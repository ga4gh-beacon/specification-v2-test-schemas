#!/usr/bin/perl

use Cwd qw(abs_path realpath);
use File::Path qw(make_path);
use File::Spec::Functions qw(catdir catfile splitdir);
use JSON::XS;
use YAML::XS qw(LoadFile DumpFile);
use Data::Dumper;

$Data::Dumper::Sortkeys = 1;
$YAML::XS::QuoteNumericStrings = 0;

binmode STDOUT, ":utf8";
my @here_path = splitdir(abs_path($0));
pop @here_path;
my $here_path = catdir(@here_path);
my $config = LoadFile(catfile($here_path, 'config.yaml')) or die "¡No config.yaml file in this path!";
bless $config;

$config->{here_path} = $here_path;
$config->{git_root_dir} = realpath($here_path.'/../..');
my $podmd = catfile($config->{git_root_dir}, $config->{podmd});

# command line input
my %args = @ARGV;
$args{-filter} ||= undef;
foreach (keys %args) { $config->{args}->{$_} = $args{$_} }

$config->_process_src();
  
exit;

################################################################################
################################################################################
# subs
################################################################################
################################################################################

sub _process_src {

	my $config = shift;

	foreach my $src_repo (@{ $config->{schema_repos} }) {
	
		foreach my $src_dir (@{ $src_repo->{schema_dirs} }) {
			my $src_path = catdir(
				$config->{git_root_dir},
				$src_repo->{project_dir},
				$src_dir
			);
			
			if (defined $config->{args}->{-filter}) {
				print "=> Filtering for $config->{args}->{-filter}\n" }
			
			# the name of the schema dir is extracted from the $id path, unless it has
			# been specified in the config, as `target_doc_dirname`.
			my $target_doc_dirname = "";			
			if ( defined $src_repo->{target_doc_dirname} ) {
				$target_doc_dirname = $src_repo->{target_doc_dirname} }
				
			opendir DIR, $src_path;
			foreach my $schema (grep{ /ya?ml$/ } readdir(DIR)) {

				my $paths = {
					schema_file => $schema,
					schema_path => catfile($src_path, $schema),
					schema_dir_path => $src_path,
					schema_dir => $src_dir,
					schema_repo => $src_repo->{project_dir},
					doc_dirname => $target_doc_dirname
				};
				
				if ( defined $src_repo->{meta_header_filename} ) {
					$paths->{meta_header_filename} = $src_repo->{meta_header_filename} }
				
				if ( defined $src_repo->{tags} ) {
					$paths->{schema_tags} = $src_repo->{tags} }
				
				if (defined $config->{args}->{-filter}) {
					if ($schema !~ /$config->{args}->{-filter}/) {
						next } }
						
				if (defined $src_repo->{include_matches}) {
					print "=> Filtering for include_matches\n";
					if (! grep{ $schema =~ /$_/ } @{ $src_repo->{include_matches} }) {
						next } }
						
				if (defined $src_repo->{exclude_matches}) {
					print "=> Filtering for exclude_matches\n";
					if (grep{ $schema =~ /$_/ } @{ $src_repo->{exclude_matches} }) {
						next } }						

				$config->_process_yaml($paths);

			}
			close DIR;

}}}

################################################################################
# main file specific process
################################################################################

sub _process_yaml {

	my $config = shift;
	my $paths = shift;

	bless $paths;
	
	print "Reading YAML file \"$paths->{schema_path}\"\n";

	my $data = LoadFile($paths->{schema_path});
	
=podmd
If a `meta_header_filename` is provided for this schema, its `meta` root parameter
is used to replace the schema's `meta`.
TODO: merge meta entries
=cut
	
	if ( defined $paths->{meta_header_filename} ) {
		my $meta = LoadFile(
			catfile(
				$paths->{schema_dir_path},
				$paths->{meta_header_filename}
			)
		);
		$data->{meta} = $meta->{meta};
	}
			
=podmd
The class name is derived from the file's "$id" value, assuming a canonical 
path structure with the class name post-pended with a version:

```
"$id": https://schemablocks.org/schemas/sb-phenopackets/Phenopacket/v0.0.1
```
Processing is skipped if the class name does contain other than word / dot / 
dash characters, or if a filter had been provided and the class name 
does not match.

=cut

	my @errors = ();

	$paths->_create_file_paths($config, $data);

	if ($data->{title} !~ /^\w[\w\.\-]+?$/) {
		push(@errors, '¡¡¡ No correct "title" value in schema '.$paths->{$schema_file}.'!') }

	if (! grep{ /^$data->{meta}->{sb_status}$/ } @{ $config->{status_levels} }) {
		push(@errors, '¡¡¡ No correct "sb_status" value in '.$paths->{$schema_file}.' => skipping !!!') }
		
	if (@errors > 0) {
		print "\n".join("\n", @errors)."\n";
		return;
	}

=podmd

The documentation is extracted from the YAML schema file and formatted into
markdown content, producing 

* a plain `.md` file in the output directories of the original repository 
(`out_dirnames.markdown`)
* the YAML header prepended file for the webpage generation

=cut

	my $output = {
		md => q{},
		jekyll_head => _create_jekyll_header($config, $paths, $data),
	};

	$output->{md} .= <<END;

<div id="schema-header-title">
  <h2><span id="schema-header-title-project">$paths->{project}</span> $data->{title} <a href="$paths->{github_repo_link}" target="_BLANK">[ &nearr; ]</a></h2>
</div>

<table id="schema-header-table">
<tr>
<th>{S}[B] Status <a href="$config->{links}->{sb_status_levels}">[i]</a></th>
<td><div id="schema-header-status">$data->{meta}->{sb_status}</div></td>
</tr>
END

	# metadata header parsing

	foreach my $attr (qw(provenance used_by contributors)) {
		if ($data->{meta}->{$attr}) {
			my $label = $attr;

			if ($attr eq 'contributors') {
				$output->{md} .= "\n\n".$config->{jekyll_excerpt_separator}."\n" }
				
			$label =~ s/\_/ /g;
			$output->{md} .= "<tr><th>".ucfirst($label)."</th><td><ul>\n";
			foreach (@{$data->{meta}->{$attr}}) {
				my $text = $_->{description}.$_->{label};
=podmd
A rudimentary CURIE to URL expansion is performed for prefixes defined in the
configuration file. An example would be the linking of an ORCID id to its web 
address.

=cut
				my $id = _expand_CURIEs($config, $_->{id});
				if ($id =~ /\:\/\/\w/) {
					$text = '<a href="'.$id.'">'.$text.'</a>' }
				elsif ($id =~ /\w/) {
					$text .=  ' ('.$id.')' }
				$output->{md} .= "<li>".$text."</li>\n";				
			}			
			$output->{md} .= "</ul></td></tr>\n";
		}
	}
	
	# / metadata header parsing

  	$output->{md} .= <<END;
<tr><th>Source ($paths->{version})</th><td><ul>
<li><a href="current/$paths->{class}.json" target="_BLANK">raw source [JSON]</a></li>
<li><a href="$paths->{github_file_link}" target="_BLANK">Github</a></li>
</ul></td></tr>
</table>

<div id="schema-attributes-title"><h3>Attributes</h3></div>

END

	foreach my $attr (grep{ $data->{$_} =~ /\w/ }  qw(type format minimum pattern description)) {
		$output->{md} .=  "  \n__".ucfirst($attr).":__ $data->{$attr}";
	}

	if (defined $data->{properties}) {
		$output->{md} = _parse_properties($data->{properties}, $output->{md}) }
	elsif (defined $data->{schemas}) {
		$output->{md} = _parse_properties($data->{schemas}, $output->{md}) }
		
	if (! defined $data->{examples}) {
		$data->{examples} = [] }
		
	if ($data->{'example'}) {
		push(@{ $data->{'examples'} }, $data->{'example'}) }

	if (@{ $data->{'examples'} } > 0) {
		$output->{md} .=  "\n\n### `$data->{title}` Value "._pluralize("Example", $data->{'examples'})."  \n\n";
		foreach (@{ $data->{'examples'} }) {
			$output->{md} .=  "```\n".JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($_)."```\n";
		}
	}


  ##############################################################################
  ##############################################################################


=podmd


=cut

	$paths->{outfile_exampels_json}->{content} = JSON::XS->new->pretty( 1 )->canonical()->encode( $data->{examples} );
	
	$paths->{outfile_plain_md}->{content} = $output->{md};
	$paths->{outfile_jekyll_current_md}->{content} = $output->{jekyll_head}.$output->{md}.$config->{schema_disclaimer}."\n";

	$paths->_export_outfiles();

}

################################################################################
################################################################################
################################################################################

################################################################################
################################################################################

sub _create_file_paths {

=podmd

Paths for output files are created based on the values (e.g. `out_dirnames` 
provided in the configuration file.

The web files for the Jekyll / GH-pages processing receive a prefix, to ensure 
that auto-generated and normal pages can co-exist. The `permalink` parameter 
provided in the YAML header of the Jekyll file provides a "nice" and stable 
name for the generated HTML page (independent of the original file name).

#### Deparsing of the class "$id"

The class "$id" values are assumed to have a specific structure, where 

* the last component is a version id
* the second-to-last component is the class name
* elements before the class name are ignored in parsing

##### Example

```
"$id": https://schemablocks.org/schemas/sb-beacon/BeaconVariant/v1.0.1
```

=cut

	my $paths = shift;
	my $config = shift;
	my $data = shift;

	my @id_comps = split('/', $data->{'$id'}); 
	$paths->{version} = pop @id_comps;
	$paths->{class} = pop @id_comps;
	$paths->{project} = pop @id_comps;
	
	my $doc_dirname = $paths->{project};
	
	if ($paths->{doc_dirname} =~ /^\w[^\/]+?\w$/) {
		$doc_dirname = $paths->{doc_dirname} }
	
	if (! $data->{examples}) {
		$data->{examples} = [] }

	my $fileClass = $paths->{schema_file};
	$fileClass =~ s/\.\w+?$//;

	_check_class_name($paths->{class}, $fileClass);
	
	print Dumper($data->{examples});

	$paths->{outfile_exampels_json} = {
		path =>  catfile(
			$config->{git_root_dir},
			$paths->{schema_repo},                      
			$config->{out_dirnames}->{examples},
			$paths->{class}.'-examples.json'
		),
		content => {},
	};
	$paths->{outfile_plain_md} = {
		path =>  catfile(
			$config->{git_root_dir},
			$paths->{schema_repo},
			$config->{out_dirnames}->{markdown},
			$paths->{class}.'.md'
		),
		content => q{}
	};
	$paths->{outfile_src_json_current} = {
		path =>  catfile(
			$config->{git_root_dir},
			$paths->{schema_repo},
			$config->{out_dirnames}->{json},
			'current',
			$paths->{class}.'.json'
		),
		content => JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
	};
	$paths->{outfile_src_json_versioned} = {
		path =>  catfile(
			$config->{git_root_dir},
			$paths->{schema_repo},
			$config->{out_dirnames}->{json},
			$paths->{version},
			$paths->{class}.'.json'
		),
		content => JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
	};
	$paths->{outfile_web_src_json_current} = {
		path =>  catfile(
		$config->{git_root_dir},
		$config->{webdocs}->{repo},
		$config->{webdocs}->{schemadir},
		$doc_dirname,
		'current',
		$paths->{class}.'.json'
		),
		content => JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
	};
	$paths->{outfile_web_src_json_versioned} = {
		path =>  catfile(
			$config->{git_root_dir},
			$config->{webdocs}->{repo},
			$config->{webdocs}->{schemadir},
			$doc_dirname,
			$paths->{version},
			$paths->{class}.'.json'
		),
		content => JSON::XS->new->pretty( 1 )->canonical()->allow_nonref->encode($data),
	};
	$paths->{outfile_jekyll_current_md} = {
		path => catfile(
		$config->{git_root_dir},
		$config->{webdocs}->{repo},
		$config->{webdocs}->{jekylldir},
		$doc_dirname,
		$config->{generator_prefix}.$paths->{class}.'.md'
		),
		content => q{}
	};
	$paths->{github_repo_link} = join('/',
		'https://github.com',
		$config->{github_organisation},
		$paths->{schema_repo},
	);
	$paths->{github_file_link} = join('/',
		'https://github.com',
		$config->{github_organisation},
		$paths->{schema_repo},
		'blob',
		'master',
		$paths->{schema_dir},
		$paths->{schema_file}
	);
	$paths->{web_link_json} = join('/',
		$config->{webdocs}->{web_schemas_rel},
		$doc_dirname,
		'current',
		$paths->{class}.'.json'
	);
	$paths->{doc_link_html} = join('/',
		$config->{webdocs}->{web_html_rel},
		$doc_dirname,
		$paths->{class}.'.html'
	);

	return $paths;

}

################################################################################
################################################################################

sub _check_class_name {

  my $sbClass   =   shift;
  my $fileClass =   shift;

  if ($sbClass ne $fileClass) {
    print <<END;
!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!

Mismatch between file name
  $fileClass
and class name from "\$id" parameter
  $sbClass

!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
END

  }
}

################################################################################
################################################################################

sub _parse_properties {

	my $props = shift;
	my $md = shift;
	
	$md .= <<END;

### Properties

<table id="schema-properties-table">
<tr><th>Property</th><th>Type</th></tr>
END

	foreach ( sort keys %{ $props } ) {
		my $label = _format_property_type_html($props->{$_});
		$md .= <<END;
<tr><th>$_</th><td>$label</td></tr>
END
	}

	$md .= "</table>\n\n";

=podmd
The property overview is followed by the listing of the properties, including
descriptions and examples.

=cut

	foreach my $property ( sort keys %{ $props } ) {

		my $p = $props->{$property};
		my $label = _format_property_type_html($p);
		my $description	= _format_property_description($p);
		$md .= <<END;

#### $property

* type: $label
END
		if ( defined $p->{value} ) {	
			$md .=  "* value: ".$p->{value}."  \n\n" }
		$md .= <<END;

$description

END
		my $propEx = _format_property_examples($p);
		if (@$propEx > 0) {
			$md .=  "##### `$property` Value "._pluralize("Example", $propEx)."  \n\n";
			foreach (@$propEx) {
				$md .= "```\n".$_."```\n";
			}
		}	
	}

	return $md;

}

################################################################################
################################################################################

sub _create_jekyll_header {

=podmd

#### Jekyll File Header

A version of the Markdown inline documentation is added to the Github (or 
alternative), Jekyll based website source tree.

The page will only be generated into an HTML page if it contains a specific 
header written in YAML.

The `_create_jekyll_header` function will pre-pend such a header to the Markdown 
page, including some file specific parameters such as the `permalink` address of 
the page.

=cut

	my $config = shift;
	my $paths = shift;
	my $data = shift;
	
	my %tags = ( $paths->{project} > 1 );
	if (defined $config->{tags}) {
		foreach (grep { /\w/ } @{$config->{tags}}) {
			$tags{$_} = 1;
		}
	}
	if (defined $paths->{schema_tags}) {
		foreach (grep { /\w/ } @{$paths->{schema_tags}}) {
			$tags{$_} = 1;
		}
	}
	if (defined $data->{meta}->{sb_status}) {
		$tags{$data->{meta}->{sb_status}} = 1 }
		
	my $j_h = <<END;
---
title: $paths->{class}
layout: default
permalink: "$paths->{doc_link_html}"
sb_status: "$data->{meta}->{sb_status}"
excerpt_separator: $config->{jekyll_excerpt_separator}
category:
  - schemas
tags:
END
	foreach (grep{ /\w/ } sort keys %tags) {
		$j_h .= "  - $_\n";
	}
	$j_h .= "---\n";
	return $j_h;

}

################################################################################
################################################################################

sub _format_property_type_html {

	my $prop_data = shift;
  
=podmd
##### Hacking the "$ref is a solitary attribute" problem

In the current JSON Schema specification there is a problem with "$ref"-type 
attribute types: If a reference is given, additional attributes of the property 
(examples, description) are being ignored. This isn't very helpful, since 
information specific to the property's _instantiation_ will not be displayed.

This behaviour can be alleviated by wrapping the `$ref` and other attributes 
with an `allof` statement (which is interpolated in the following, to expose 
the attributes). We'll hope for a more elegant solution ...

=cut

	$prop_data = _remap_allof($prop_data);
		  
	my $typeLab;
	my $type = q{};
	my $isRef = \0;
	
	if ($prop_data->{type}) {
		$type = $prop_data->{type} }
	if (
		$type !~ /.../
		&&
		$prop_data->{'$ref'} =~ /.../
	) {
		$isRef = 1;
		$typeLab = $prop_data->{'$ref'};
	} elsif ($type =~ /array/) {
		if ($prop_data->{items}->{'$ref'} =~ /.../) {
			$isRef = 1;
			$typeLab  =  $prop_data->{items}->{'$ref'};
		} elsif ( ref($prop_data->{items}) !~ /HASH/ ) {
			$typeLab =   $prop_data->{items} }
		else {
			$typeLab =   $prop_data->{items}->{type} }
	} else {
		$typeLab = $type;
		if ($prop_data->{"format"} =~ /.../) {
			$typeLab .=	' ('.$prop_data->{"format"}.')' }
	}

	if ($isRef) {
		$typeLab = _format_link($typeLab) }

	if ($type =~ /array/) {
		$typeLab = 'array of "'.$typeLab.'"' }

	return $typeLab;

}

################################################################################

sub _format_link {

	my $ref = shift;
	
	if ($ref =~ /^(\w+?\.\w+?)(#\/.*?)?$/) {
		my $html = $1;
		$html =~ s/\.\w+?$/.html/;
		$html =~ s/v\d+?\.\d+?\.\d+?\///;
		return $ref.' [<a href="./'.$html.'">HTML</a>]';
	} elsif ($ref =~ /(^http.+?\.\w+?)(#.*?)?$/) {
		return $ref.' [<a href="'.$1.'">LINK</a>]';
	} else {
		return $ref;
	}

}


################################################################################
################################################################################

sub _remap_allof {

=podmd
##### Helper `_remap_allof`

This function remaps the list of property attributes required from using a 
'$ref' property definition to a standard object, which is then processed for
documentation in the usual way.

TODO: 
* be aware of the possibility of multiple "$ref" elements (not in the {S}[B]
specifications right now) which would being reduced to one
* hoping for _JSON Schema_ to fix the "$ref" format requirement ...

=cut

	my $prop_data = shift;
	my $prop = {};

	if (ref($prop_data) !~ /HASH/) {
		return $prop_data }
	if (! $prop_data->{allof}) {
		return $prop_data }

	foreach my $of (@{ $prop_data->{allof} }) {		  
		if ((keys %$of )[0] eq '$ref') {
			$prop->{'$ref'} = $of->{'$ref'} }
		else {
			foreach (sort keys %$of) {
				$prop->{$_} = $of->{$_};
			}
		}	  
	}

	return $prop;
  
}
 
################################################################################
################################################################################

sub _format_property_description {

	my $prop_data = shift;
	$prop_data = _remap_allof($prop_data);

	return $prop_data->{description};

}

################################################################################
################################################################################

sub _format_property_examples {

=podmd

=cut

	my $prop_data = shift;
	my $ex_md = [];	
	$prop_data = _remap_allof($prop_data);
	
	if (! defined $prop_data->{examples}) {
		$prop_data->{examples} = [] }
	
	if ($prop_data->{'example'}) {
		push(@{ $prop_data->{'examples'} }, $data->{'prop_data'}) }

	foreach my $example (@{ $prop_data->{'examples'} }) {
		if (grep { $prop_data->{type} =~ /$_/ } qw(num int) ) {
			$example *= 1 }
		elsif (
			($prop_data->{type} eq 'array')
			&&
			(grep { $prop_data->{items}->{type} =~ /$_/ } qw(num int) )
		) {
			my $ti = [ ];
			foreach (@$example) {
				push(@$ti, $_ *= 1);
			}
			$example = $ti;		
		}
		push(@$ex_md, JSON::XS->new->pretty( 1 )->allow_nonref->canonical()->encode($example));
	}

	return $ex_md;

}

################################################################################
################################################################################
=podmd

### Helper Subroutines

=cut
################################################################################
################################################################################

sub _expand_CURIEs {

=podmd
#### `_expand_CURIEs`

This function expands prefixes in identifiers, based on the parameters provided 
in `config.yaml`. This is thought as a helper for some script/website specific 
linking, not as a general CURIE expansion utility.

=cut

	my $config = shift;
	my $curie = shift;
	
	if (grep{ $curie =~ /^$_\:/ } keys %{ $config->{prefix_expansions} }) {
		my $pre = (grep{ $curie =~ /^$_\:/ } keys %{ $config->{prefix_expansions} })[0];
		$curie =~ s/$pre\:@?/$config->{prefix_expansions}->{$pre}/;
	}
	
	return $curie;

}

################################################################################
################################################################################

sub _export_outfiles {

	my $paths = shift;
	
	foreach (grep{ /outfile_/} keys %{ $paths }) {

		print "\n=> $paths->{$_}->{path}\n";
		my $dir = $paths->{$_}->{path};
		$dir =~ s/\/[^\/]+?\.\w+?$//;
		if (! -d $dir) {
			make_path($dir) }
		open  (FILE, ">", $paths->{$_}->{path}) || warn '!!! output file '. $paths->{$_}->{path}.' could not be created !!!';
		print FILE  $paths->{$_}->{content}."\n";
		close FILE;
		
	}
  
}

################################################################################
################################################################################

sub _pluralize {

	my $word = shift;
	my $list = shift;
	if (@$list > 1) {
		$word .= 's' }
	return $word;

}
