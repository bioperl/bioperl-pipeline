#!/usr/local/bin/perl


BEGIN{
	use lib 't';
	use Test;
	plan tests => 3;
}

use BiopipeTestDB;
use Bio::Pipeline::SQL::DBAdaptor;
use Bio::Pipeline::SQL::ConverterAdaptor;
use Bio::Pipeline::Converter;

ok(1);

my $biopipe_test = BiopipeTestDB->new();

$biopipe_test->do_sql_file("t/data/debut.converter.init.sql"); 

my $dba = $biopipe_test->get_DBAdaptor();

my $ca = new Bio::Pipeline::SQL::ConverterAdaptor($dba);

my $converter = $ca->fetch_by_dbID("1");

ok $converter->isa("Bio::Pipeline::Converter");

$module = $converter->module;

ok $module, "Bio::SeqFeatureIO";

ok 1;
