#! /usr/local/bin/perl

BEGIN{
  use lib 't';
  use Test;
  plan tests=>3; 
}

use Bio::SearchIO;
use Bio::Pipeline::Utils::Filter;


my $searchio = Bio::SearchIO->new ('-format' => 'blast',
                                   '-file'   => "t/data/blast.report");


my @hsps;
while (my $r = $searchio->next_result){
   while(my $hit = $r->next_hit){
     push @hsps, $hit->hsps;
   }
}

my $filter = new Bio::Pipeline::Utils::Filter ( -module=>'feature_filter',
												-condition => '<=',
												-tag => 'evalue',
												-threshold=> '0.00001'
												);
ok $filter;

ok my $filtered = $filter->run(\@hsps);

ok scalar @{$filtered},4;

