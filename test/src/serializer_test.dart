part of serializers_test;

class Person {
  String firstName;
  String lastName;

  Person(this.firstName, this.lastName);

  get fullName => "$firstName $lastName";

  operator [](prop){
    if(prop == 'firstName'){
      return firstName;
    } else if(prop == 'lastName') {
      return lastName;
    } else {
      return null;
    }
  }
}

class SubPerson extends Person {
  SubPerson(firstName, lastName) : super(firstName, lastName);
}

class DefaultSerializer extends Serializer<Person>{
}

class SerializerWithRoot extends Serializer<Person>{
  get fields => ["firstName"];
  get root => "person";
}

class SerializerWithPostProcessing extends Serializer<Person>{

  postProcessing(map, model) => {"postProcessing" : true};
}

class SelectedFieldsSerializer extends Serializer<Person>{
  var fields;
  SelectedFieldsSerializer(this.fields);
}

class CustomFieldsSerializer extends Serializer<Person>{
  get custom => {
    'transformed' : (Person person) => "TRANSFORMED ${person.firstName}"
  };
}

testSerializer(){
  group("[serializer]", (){
    group("[object]", (){
      group("[sync]", (){
        var person;

        setUp((){
          person = new Person("Bill", "Evans");
        });

        test("serializes all the fields of the object", (){
          var json = new DefaultSerializer().serialize(person, object: true);
          var expected = {"firstName" : "Bill", "lastName" : "Evans", "fullName" : "Bill Evans"};
          expect(json, equals(expected));
        });

        test("serializes selected fields of the object", (){
          var json = new SelectedFieldsSerializer(["firstName"]).serialize(person, object: true);
          var expected = {"firstName" : "Bill"};
          expect(json, equals(expected));
        });

        test("serializes computed fields of the object", (){
          var json = new SelectedFieldsSerializer(["fullName"]).serialize(person, object: true);
          var expected = {"fullName" : "Bill Evans"};
          expect(json, equals(expected));
        });

        test("serializes custom fields", (){
          var json = new CustomFieldsSerializer().serialize(person, object: true);
          var expected = {"transformed" : "TRANSFORMED Bill"};
          expect(json, equals(expected));
        });

        test("wraps the result into the root tag", (){
          var json = new SerializerWithRoot().serialize(person, object: true);
          var expected = {"person" : {"firstName" : "Bill"}};
          expect(json, equals(expected));
        });

        test("runs post processing hook", (){
          var json = new SerializerWithPostProcessing().serialize(person, object: true);
          var expected = {"postProcessing" : true};
          expect(json, equals(expected));
        });

        group("[subclass]", (){
          var person;

          setUp((){
            person = new SubPerson("Bill", "Evans");
          });

          test("does not serialize the fields of the superclass by default", (){
            var json = new DefaultSerializer().serialize(person, object: true);
            expect(json, equals({}));
          });

          test("serialize specified properties of the superclass", (){
            var json = new SelectedFieldsSerializer(["firstName"]).serialize(person, object: true);
            var expected = {"firstName" : "Bill"};
            expect(json, equals(expected));
          });
        });
      });

      group("[async]", (){
        var person;

        setUp((){
          person = new Person("Bill", "Evans");
        });

        test("serializes selected fields of the object", (){
          var future = new SelectedFieldsSerializer(["firstName", "lastName"]).serializeAsync(person, object: true);
          future.then(expectAsync1((json){
            var expected = {"firstName" : "Bill", "lastName" : "Evans"};
            expect(json, equals(expected));
          }));
        });

        test("serializes custom fields", (){
          var future = new CustomFieldsSerializer().serializeAsync(person, object: true);
          future.then(expectAsync1((json){
            var expected = {"transformed" : "TRANSFORMED Bill"};
            expect(json, equals(expected));
          }));
        });

        test("throws an exception when invalid field", (){
          var future = new SelectedFieldsSerializer(["invalid"]).serializeAsync(person, object: true);
          future.catchError(expectAsync1((error){}));
        });

        test("runs post processing hook", (){
          var future = new SerializerWithPostProcessing().serializeAsync(person, object: true);
          future.then(expectAsync1((json){
            var expected = {"postProcessing" : true};
            expect(json, equals(expected));
          }));
        });
      });
    });

    group("[map]", (){
      var person;

      setUp((){
        person = new Person("Bill", "Evans");
      });

      test("serializes selected fields of the object", (){
        var json = new SelectedFieldsSerializer(["firstName"]).serialize(person, map: true);
        var expected = {"firstName" : "Bill"};
        expect(json, equals(expected));
      });

      test("defauls missing fields to null", (){
        var json = new SelectedFieldsSerializer(["invalid"]).serialize(person, map: true);
        var expected = {"invalid" : null};
        expect(json, equals(expected));
      });

      test("works in async mode", (){
        var future = new SelectedFieldsSerializer(["firstName"]).serializeAsync(person, map: true);
        future.then(expectAsync1((json){
          var expected = {"firstName" : "Bill"};
          expect(json, equals(expected));
        }));
      });
    });
  });
}