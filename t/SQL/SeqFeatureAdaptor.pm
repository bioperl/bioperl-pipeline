

package SQL::SeqFeatureAdaptor;
use vars qw(@ISA);
use strict;

# Object preamble - inherits from Bio::Root::RootI

use Bio::DB::SQL::BaseAdaptor;
use Bio::SeqFeature::Generic;

@ISA = qw(Bio::DB::SQL::BaseAdaptor);

sub _table {"seqfeature"}

# new is inherieted


sub store {
   my ($self, @features) = @_;
   if (defined(	@features)) {
    my $num = scalar(@features);
     print "No of features : $num\n";
     my $feat = @features[0];
     my $seqname = $feat->seqname;
     my $start = $feat->start;
     my $end = $feat->end;
     my $score = $feat->score;
     my $strand = $feat->strand;
     print "Feature Information .................\n";
     print "Seq name : $seqname\n";    
     print "start : $start\n";    
     print "end : $end\n";    
     print "strand : $strand\n";    
     print "score : $score\n";    
     print "..................\n";
   }
   else {
     print "No features to output";
   }

}

