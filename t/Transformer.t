#! /usr/local/bin/perl

BEGIN{
  use lib 't';
  use Test;
  plan tests=>4; 
}

use Bio::SearchIO;
use Bio::Pipeline::Transformer;
use Bio::Pipeline::Method;
use Bio::Pipeline::Argument;


my $searchio = Bio::SearchIO->new ('-format' => 'blast',
                                   '-file'   => "t/data/blast.report");


my @hsps;
while (my $r = $searchio->next_result){
   while(my $hit = $r->next_hit){
     push @hsps, $hit->hsps;
   }
}
my @args;
push @args , Bio::Pipeline::Argument->new(-tag=>"-module",
                                         -value=>"feature_filter");
push @args , Bio::Pipeline::Argument->new(-tag=>"-tag",
                                         -value=>"evalue");
push @args, Bio::Pipeline::Argument->new(-tag=>"-threshold", 
                                         -value=>"0.00001");
push @args, Bio::Pipeline::Argument->new(-tag=>"-condition", 
                                         -value=>"<=");
my @meth;
push @meth , Bio::Pipeline::Method->new(-name=>"new",
                                        -argument=>\@args);
@arg = (Bio::Pipeline::Argument->new( -value=>"INPUT"));

push @meth , Bio::Pipeline::Method->new(-name=>"run",
                                        -argument=>\@arg);

my $trans  = new Bio::Pipeline::Transformer(-module=>"Bio::Pipeline::Utils::Filter",
                                            -method=>\@meth);
ok scalar @{$trans->method}, 2;
ok $trans->module, "Bio::Pipeline::Utils::Filter";

ok my $filtered = $trans->run(\@hsps);

ok scalar @{$filtered},4;

