#!/usr/local/bin/perl

use strict;

BEGIN{
	use lib 't';
	use Test;
	plan tests => 29;
}

use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::SQL::ConverterAdaptor;
use Bio::Pipeline::Converter;


my $biopipe_test = BiopipeTestDB->new();
$biopipe_test->do_sql_file("t/data/debut.converter.init.sql"); 

my $dba = $biopipe_test->get_DBAdaptor();
my $ca = new Bio::Pipeline::SQL::ConverterAdaptor($dba);

my $converter = $ca->fetch_by_dbID("1");
&_check_converter($converter, 1, "Bio::SeqFeatureIO");


$converter = new Bio::Pipeline::Converter(
	-dbid => 10,
	-module => "foomodule"
);

my @converter_methods;
for(my $i=0; $i<3; $i++){
	my $converter_method = new Bio::Pipeline::DataHandler(
		-dbID => 100+$i,
		-method => "method$i",
		-rank => 1+$i
	);
	push @converter_methods, $converter_method;
}
$converter->method(\@converter_methods);

$ca->store($converter);


ok 1;

$converter = $ca->fetch_by_dbID(10);


ok $converter->module, "foomodule";

my @methods = @{$converter->method}; 
ok scalar(@methods), 3;

foreach my $method (@methods){



}


# internal methods to help test
sub _check_converter{
	my ($converter, $dbID, $module) = @_;

	ok $converter->isa("Bio::Pipeline::Converter");
	ok $converter->dbID, $dbID;
	$module = $converter->module;
	ok $module, $module;

	my @methods = @{$converter->method};

	foreach my $method (@methods){

		if($method->dbID == 1){
			&_check_converter_method($method, 1, 'new', 1);
		}elsif($method->dbID == 2){
			&_check_converter_method($method, 2, 'convert', 2);
		}	
	
	}
}

sub _check_converter_method{
	my ($method, $dbID, $method_name, $rank) =@_;
	ok ref($method), 'Bio::Pipeline::DataHandler';
	ok $method->dbID, $dbID;
	ok $method->method, $method_name;
	ok $method->rank, $rank;
	
	my @arguments = @{$method->argument};

	return unless $#arguments >= 0;
		 
	foreach my $argument (@arguments){
		my $argument_id = $argument->dbID;
		if($argument_id ==1 && $dbID == 1){
			&_check_converter_argument($argument, 1, '-in', 'Bio::SeqFeature::Gene::GeneStructure',1);
		}elsif($argument_id == 2 && $dbID == 1){
			&_check_converter_argument($argument, 2, '-out', 'Bio::EnsEMBL::Gene',2);
		}elsif($argument_id ==3 && $dbID == 2){
			&_check_converter_argument($argument, 3, '-input', 'INPUT',3);
		}
	}


}

sub _check_converter_argument{
	my ($argument, $dbID, $tag, $value, $rank) = @_;
	ok ref($argument), 'Bio::Pipeline::Argument';
	ok $argument->dbID, $dbID;
	ok $argument->tag, $tag;
	ok $argument->value, $value;
	ok $argument->rank, $rank;
}


