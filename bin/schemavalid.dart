#!/usr/bin/env dart
/// 
/// Usage: schemavalid --schema INPUT_SCHEMA_URI --json INPUT_JSON_URI --key KEY
///
/// Given a schema uri [schema], json uri [json] and key [key]
/// validate the json starting at key against the schema
///

import 'dart:async';
import 'dart:convert' as convert;
import 'dart:io';
import 'dart:math';
import 'package:args/args.dart';
import 'package:json_schema/json_schema.dart';
import 'package:json_schema/schema_dot.dart';
import 'package:logging/logging.dart';

//! The parser for this script
ArgParser _parser;

//! The comment and usage associated with this script
void _usage() { 
  print('''

Usage: schemavalid --schema INPUT_SCHEMA_URI --json INPUT_JSON_URI [--k KEY] [--array ARRAY]

Given a schema uri [schema], json uri [json] and key [key]
validate the json starting at key against the schema

''');
  print(_parser.getUsage());
}

//! Method to parse command line options.
//! The result is a map containing all options, including positional options
Map _parseArgs(args) { 
  ArgResults argResults;
  Map result = { };
  List remaining = [];

  _parser = new ArgParser();
  try { 
    /// Fill in expectations of the parser
    _parser.addOption('schema', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 's',
      allowed: null);
    _parser.addOption('json', 
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'j',
      allowed: null);
    _parser.addOption('key',
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'k');
    _parser.addOption('array',
      defaultsTo: null,
      allowMultiple: false,
      abbr: 'a');

    /// Parse the command line options (excluding the script)
    var arguments = args;
    argResults = _parser.parse(arguments);
    argResults.options.forEach((opt) { 
      result[opt] = argResults[opt];
    });
    
    return { 'options': result, 'rest': remaining };

  } catch(e) { 
    _usage();
    throw e;
  }
}

final _logger = new Logger("schemavalid");

main(List<String> args) { 
  Logger.root.onRecord.listen((LogRecord r) =>
      print("${r.loggerName} [${r.level}]:\t${r.message}"));
  Logger.root.level = Level.WARNING;
  Map argResults = _parseArgs(args);

  Map options = argResults['options'];
  List positionals = argResults['rest'];

  try { 
    if(options["schema"] == null)
      throw new ArgumentError("option: schema is required");

    if(options["json"] == null)
      throw new ArgumentError("option: json is required");

  } on ArgumentError catch(e) { 
    print(e);
    _usage();
  }
  // custom <schemavalid main>

  Completer schemaCompleter = new Completer();

  //download the schema
  Uri suri = Uri.parse(options['schema']);
  if (suri.scheme == 'http' || suri.scheme == 'https') {

    new HttpClient().getUrl(suri).then((HttpClientRequest request) => request.close())
      .then((HttpClientResponse response) =>
          response.transform(new convert.Utf8Decoder()).join())
      .then((text) {
        schemaCompleter.complete(text);
      });

  }
  else {

    File target = new File(suri.toString());
    if(target.existsSync()) {
      schemaCompleter.complete(target.readAsStringSync());
    }
    else {
      print('file does not exist');
    }
  }

  schemaCompleter.future.then((schemaText) {
    Future schema = Schema.createSchema(convert.JSON.decode(schemaText));
    schema.then((schema) {

      Completer jsonCompleter = new Completer();

      Uri juri = Uri.parse(options['json']);
      if (juri.scheme == 'http' || juri.scheme == 'https') {

        new HttpClient().getUrl(juri).then((HttpClientRequest request) => request.close())
          .then((HttpClientResponse response) =>
              response.transform(new convert.Utf8Decoder()).join())
          .then((text) {
            jsonCompleter.complete(text);
          });
      }
      else {

        File target = new File(juri.toString());
        if(target.existsSync()) {
          jsonCompleter.complete(target.readAsStringSync());
        }
        else {
          print('file does not exist');
        }

      }

      jsonCompleter.future.then((jsonText) {
        var json = convert.JSON.decode(jsonText);

        if (options['array'] != null) {
          //when doing an array raise the log level
          Logger.root.level = Level.SEVERE;

          var keys = options['array'].split('.');
          for (var k = 0; k < keys.length; ++k) {
            json = json[keys[k]];
          }

          for (var i = 0; i < json.length; ++i) {
            if (schema.validate(json[i])) {
              print(i.toString() + ' was valid');
            }
            else {
              print(i.toString() + ' was invalid');
              print(json[i]);
            }
          }
        }
        else {
          if (options['key'] != null) {
            json = json[options['key']];
          }
          print(schema.validate(json));
        }
      });

    });
  });

  // end <schemavalid main>

}

// custom <schemavalid global>

// end <schemavalid global>


