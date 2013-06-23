part of serializers;

abstract class Serializer<T> {
  List<String> get fields => [];

  String get root => null;

  Map get custom => {};

  Map postProcessing(Map serialized, T model){
    return serialized;
  }

  Map serialize(T m, {bool map: false}){
    var propertyReader = (map == true) ? _mapBasedPropertyReader : _mirrorBasedPropertyReader;
    return new _Serializer(m, this, propertyReader).serialize();
  }
}

class _Serializer {
  var model, propertyReader;
  Serializer serializer;

  _Serializer(this.model, this.serializer, this.propertyReader);

  readFromSerializer(String field) => serializer.custom[field](model);

  serialize(){
    var res = fields.fold({}, (Map memo, String field) {
      if (serializerOverrides(field)) {
        memo[field] = readFromSerializer(field);
      } else {
        memo[field] = this.propertyReader(this.model, field);
      }
      return memo;
    });
    return postProcessing(res);
  }

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
      var variables = cm.variables.values.toList()..addAll(cm.getters.values.toList());
      return variables.map((_) => MirrorSystem.getName(_.simpleName)).toList();
    } else {
      return serializer.custom.keys.toList()..addAll(serializer.fields);
    }
  }
}

_mirrorBasedPropertyReader(model, String field ) => reflect(model).getField(new Symbol(field)).reflectee;

_mapBasedPropertyReader(model, String field ) => model[field];