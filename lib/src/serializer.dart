part of serializers;

abstract class Serializer<T> {
  List<String> get fields => [];

  String get root => null;

  Map get custom => {};

  Map postProcessing(Map serialized, T model){
    return serialized;
  }

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
      return new Future.sync(() => new _MapSerializer(m, this).serialize());
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

  readFromModel(String field);

  readFromSerializer(String field);

  serialize();

  serializerOverrides(String field) =>
    serializer.custom.containsKey(field);

  Map postProcessing(Map res){
    var withRoot = {};
    if(serializer.root != null){
      withRoot[serializer.root] = res;
    } else {
      withRoot = res;
    }
    return serializer.postProcessing(withRoot, model);
  }

  List<String> get fields {
    if(serializer.fields.isEmpty && serializer.custom.isEmpty){
      ClassMirror cm = reflect(model).type;
      var variables = cm.variables.values.toList()..addAll(cm.getters.values);
      return variables.map((_) => MirrorSystem.getName(_.simpleName)).toList();
    } else {
      return serializer.custom.keys.toList()..addAll(serializer.fields);
    }
  }
}

class _SyncSerializer extends _BaseSerializer {
  _SyncSerializer(model, serializer) : super(model, serializer);

  serialize(){
    var res = fields.fold({}, (Map res, String field) {
      if (serializerOverrides(field)) {
        res[field] = readFromSerializer(field);
      } else {
        res[field] = readFromModel(field);
      }
      return res;
    });
    return postProcessing(res);
  }

  readFromSerializer(String field) => serializer.custom[field](model);

  readFromModel(String field) {
    var value = deprecatedFutureValue(reflect(model).getFieldAsync(new Symbol(field)));

    if (value is MirroredCompilationError) {
      throw new SerializerConfigurationError(model, field);
    }
    return value.reflectee;
  }
}

class _AsyncSerializer extends _BaseSerializer {
  _AsyncSerializer(model, serializer) : super(model, serializer);

  serialize() =>
    Future.wait(pairs()).then((pairs){
      var res = pairs.fold({}, (res, p){
        res[p[0]] = p[1];
        return res;
      });
      return postProcessing(res);
    });

  pairs() =>
    fields.map((_) => serializerOverrides(_) ? readFromSerializer(_) : readFromModel(_));

  readFromSerializer(String field) =>
    new Future.value([field, serializer.custom[field](model)]);

  readFromModel(String field) =>
    reflect(model).
      getFieldAsync(new Symbol(field)).
      then((v) => [field, v.reflectee]).
      catchError((e){throw new SerializerConfigurationError(model, field);});
}

class _MapSerializer extends _BaseSerializer {
  _MapSerializer(model, serializer) : super(model, serializer);

  serialize(){
    var res = fields.fold({}, (Map res, String field) {
      if (serializerOverrides(field)) {
        res[field] = readFromSerializer(field);
      } else {
        res[field] = readFromModel(field);
      }
      return res;
    });
    return postProcessing(res);
  }

  readFromSerializer(String field) => serializer.custom[field](model);

  readFromModel(String field) => model[field];
}
