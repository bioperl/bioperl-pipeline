#!/usr/local/bin/perl


BEGIN{
	use lib 't';
	use Test;
	plan tests => 6;
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

print "finishing the fetch test, and starting the store test\n";

# internal methods to help test
sub _check_converter{
	my ($converter, $dbID, $module) = @_;

	ok $converter->isa("Bio::Pipeline::Converter");
	ok $converter->dbID, $dbID;
	my $module = $converter->module;
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


		 
	foreach my $argument (@arguments){
		my $argument_id = $argument->dbID;
		if($argument_id ==1 && $dbID == 1){
			&_check_converter_argument($argument, 1, '-in', 'Bio::SeqFeature::Gene::GeneStructure');
		}elsif($argument_id == 2 && $dbID == 1){
			&_check_converter_argument($argument, 2, '-out', 'Bio::EnsEMBL::Gene');
		}elsif($argument_id ==3 && $dbID == 2){
			&_check_converter_argument($argument, 3, '-input', 'INPUT');
		}else{
			print "error\n";
		}
	}



}

sub _check_converter_argument{
	my ($argument, $dbID, $tag, $value) = @_;
	ok ref($argument), 'Bio::Pipeline::Argument';
	ok $argument->dbID, $dbID;
	ok $argument->tag, $tag;
	ok $argument->value, $value;
}


