#!/usr/local/bin/python3

import sys, re
from ruamel.yaml import YAML
from os import path as path
import argparse

# local
dir_path = path.dirname(path.abspath(__file__))

"""podmd

The `sbOpenAPIparser` tool reads schema files defined using OpenAPI and extracts
the embedded schemas as individual YAML documents, with an added metadata header
compatible to use in [SchemaBlocks](https://schemablocks.org/categories/schemas.html)
schema documents.

##### Examples

* `python3 sbOpenAPIparser.py -o ~/GitHub/ga4gh-schemablocks/sb-discovery-search/schemas/ -f ~/GitHub/ga4gh-schemablocks/sb-discovery-search/source/search-api.yaml -p "sb-discovery-search" -m ~/GitHub/ga4gh-schemablocks/sb-discovery-search/source/header.yaml`

podmd"""

################################################################################
################################################################################
################################################################################

def _get_args():

    parser = argparse.ArgumentParser()
    parser.add_argument("-o", "--outdir", help="path to the output directory")
    parser.add_argument("-f", "--schemafile", help="OpenAPI schema file to be ripped apart")
    parser.add_argument("-m", "--headerfile", help="SchemaBlocks format metadata header")
    parser.add_argument("-p", "--project", help="Project id")

    args = parser.parse_args()

    return(args)

################################################################################

def main():

    """podmd

    A single-file OpenAPI schema is read in from a YAML file, and the
    `components.schemas` object is iterated over, extracting each individual
    schema.

    This schema is updated with metadata, either from a provided SchemaBlocks
    header file or with a default from `config.yaml`.

    Some of the parameter values are adjusted (which probably will have to be
    expanded for different use cases); e.g. the internal reference paths
    are interpreted as pointing to individual schema files in the current
    directory.

    end_podmd"""

    yaml = YAML()
    yaml.indent(mapping=2, sequence=4, offset=2)

    with open( path.join( path.abspath( dir_path ), "config.yaml" ) ) as cf:
        config = yaml.load( cf )

    args = _get_args()
    _check_args(config, args)

    with open( config[ "schemafile" ] ) as f:
        oas = yaml.load( f )

    if path.isfile( config[ "headerfile" ] ):
        with open( config[ "headerfile" ] ) as f:
            config.update( { "header": yaml.load( f ) } )

    _config_add_project_specs(config, oas)

    for s_name in oas["components"]["schemas"].keys():

        f_name = s_name+".yaml"
        print(f_name)

        s = oas["components"]["schemas"][ s_name ]
        _add_header(config, s, s_name)
        _fix_relative_ref_paths(s)

        if "$id" in s:
            s[ "$id" ] = re.sub( r"__schema__", s_name, s[ "$id" ] )
            s[ "$id" ] = re.sub( r"__project__", config[ "project" ], s[ "$id" ] )

        ofp = path.join( config[ "outdir" ], f_name )
        with open(ofp, 'w') as of:
            docs = yaml.dump(s, of)

################################################################################

def _check_args(config, args):

    if config[ "outdir" ]:
        config.update({ "outdir": path.join( path.abspath( dir_path ), path.abspath( dir_path ), config[ "outdir" ]) } )
    if config[ "schemafile" ]:
        config.update({ "schemafile": path.join( path.abspath( dir_path ), path.abspath( dir_path ), config[ "schemafile" ]) } )

    for a in vars(args).keys():
        if vars(args)[a]:
            config.update({ a: vars(args)[a] })

    if not config[ "project" ]:
        print("No project name has been provided; please use `-p` to specify")
        sys.exit( )

    if not path.isdir( config[ "outdir" ] ):
        print("""
The output directory:
    {}
...does not exist; please use `-o` to specify
""".format(config[ "outdir" ]))
        sys.exit( )

    if not path.isfile( config[ "schemafile" ] ):
        print("No inputfile has ben given; please use `-f` to specify")
        sys.exit( )

    return config

################################################################################

def _config_add_project_specs(config, oas):

    h_k_n = len( config["header"].keys() )

    if "info" in oas:
        if "version" in oas[ "info" ]:
            config["header"].update( { "$id" : re.sub( r"__version__", oas["info"][ "version" ], config["header"]["$id" ]) } )
            config["header"].insert(h_k_n, "version", oas["info"][ "version" ])

    return config

################################################################################

def _add_header(config, s, s_name):

    pos = 0

    for k, v in config[ "header" ].items():
        s.insert(pos, k, v)
        pos += 1

    s.insert(pos, "title", s_name)

    return s

################################################################################

def _fix_relative_ref_paths(s):

    """podmd
    The path fixes here are very much "experience driven" and should be replaced
    with a more systematic version, including existence & type checking ...
    podmd"""

    properties = s
    if "properties" in s:
        properties = s[ "properties" ]

    for p in properties.keys():

        if '$ref' in properties[ p ]:
            properties[ p ][ '$ref' ] = re.sub( '#/components/schemas/', '', properties[ p ][ '$ref' ] ) + '.yaml#/'
        if 'items' in properties[ p ]:
            if '$ref' in properties[ p ][ "items" ]:
                properties[ p ][ "items" ][ '$ref' ] = re.sub( '#/components/schemas/', '', properties[ p ][ "items" ][ '$ref' ] ) + '.yaml#/'

        if "properties" in s:
            s[ "properties" ].update( { p: properties[ p ] } )
        else:
            s.update( { p: properties[ p ] } )

    if "oneOf" in s:
        o_o = [ ]
        for o in s[ "oneOf" ]:
            if "$ref" in o.keys():
                v = re.sub( '#/components/schemas/', '', o["$ref"] ) + '.yaml#/'
                o_o.append( { "$ref": v} )
            else:
                o_o.append( o )
        s.update( { "oneOf": o_o } )

    return s

################################################################################
################################################################################
################################################################################

if __name__ == '__main__':
    main(  )
