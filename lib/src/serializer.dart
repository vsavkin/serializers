part of serializers;

abstract class Serializer<T> {
  get fields => [];

  get custom => {};

  Map serialize(T m, {bool object, bool map}){
    if(object == true){
      return new _SyncSerializer(m, this).serialize();
    } else {
      return new _MapSerializer(m, this).serialize();
    }
  }

  Future<Map> serializeAsync(T m, {bool object, bool map}){
    if(object == true){
      return new _AsyncSerializer(m, this).serialize();
    } else {
      return new Future.of(() => new _MapSerializer(m, this).serialize());
    }
  }
}

class SerializerConfigurationError implements Exception {
  var model, fieldName;

  SerializerConfigurationError(this.model, this.fieldName);

  String toString() => "SerializerConfigurationError :: Cannot serialize '${fieldName}' of '${model}'";
}

abstract class _BaseSerializer {
  var model;
  Serializer serializer;

  _BaseSerializer(this.model, this.serializer);

  readFromModel(field);

  readFromSerializer(field);

  serializerOverrides(field) =>
    serializer.custom.containsKey(field);

  serialize() =>
    fields.reduce({}, (Map res, String field) {
      if(serializerOverrides(field)){
        res[field] = readFromSerializer(field);
      } else {
        res[field] = readFromModel(field);
      }
      return res;
    });

  List get fields {
    if(serializer.fields.isEmpty && serializer.custom.isEmpty){
      ClassMirror cm = reflect(model).type;
      return cm.variables.keys.toList()..addAll(cm.getters.keys);
    } else {
      return serializer.custom.keys.toList()..addAll(serializer.fields);
    }
  }
}

class _SyncSerializer extends _BaseSerializer {
  _SyncSerializer(model, serializer) : super(model, serializer);

  readFromSerializer(field) => serializer.custom[field](model);

  readFromModel(field) {
    var value = deprecatedFutureValue(reflect(model).getField(field));
    if (value is AsyncError) {
      throw new SerializerConfigurationError(model, field);
    }
    return value.reflectee;
  }
}

class _AsyncSerializer extends _BaseSerializer {
  _AsyncSerializer(model, serializer) : super(model, serializer);

  serialize() =>
    Future.wait(pairs()).then((pairs) =>
      pairs.reduce({}, (res, p){
        res[p[0]] = p[1];
        return res;
      })
    );

  pairs() =>
    fields.map((field) => serializerOverrides(field) ? readFromSerializer(field) : readFromModel(field));

  readFromSerializer(field) =>
    new Future.immediate([field, serializer.custom[field](model)]);

  readFromModel(field) =>
    reflect(model).
      getField(field).
      then((v) => [field, v.reflectee]).
      catchError((e){throw new SerializerConfigurationError(model, field);});
}

class _MapSerializer extends _BaseSerializer {
  _MapSerializer(model, serializer) : super(model, serializer);

  readFromSerializer(field) => serializer.custom[field](model);

  readFromModel(field) => model[field];
}
