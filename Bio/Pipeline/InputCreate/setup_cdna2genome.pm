#
# BioPerl module for Bio::Pipeline::InputCreate::setup_cdna2genome
#
# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Input::setup_cdna2genome

=head1 SYNOPSIS

  my $inc = Bio::Pipeline::Input::setup_cdna2genome->new(-contig_ioh=>$cioh,
                                                   -protein_ioh=>$pioh,
                                                   -dh_ioh     =>$dh_ioh,
                                                   -padding => 1000);
  $inc->run;

=head1 DESCRIPTION

The input/output object for reading input and writing output.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org                  - General discussion
  http://bioperl.org/wiki/Mailing_lists  - About the mailing lists

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut

package Bio::Pipeline::InputCreate::setup_cdna2genome;

use vars qw(@ISA);

use strict;
use Bio::Pipeline::InputCreate;
use Bio::Pipeline::DataType;
use Bio::Root::IO;
use Bio::SearchIO;

@ISA = qw(Bio::Pipeline::InputCreate);

sub _initialize {
    my ($self,@args) = @_;
    $self->SUPER::_initialize(@args);

    my ($cdna_ioh,$genome_ioh) = $self->_rearrange([qw(CDNA_IOH GENOME_IOH)],@args);

    $genome_ioh || $self->throw("Need an iohandler for the genome");
    $self->genome_ioh($genome_ioh);

    $cdna_ioh || $self->throw("Need an iohandler for the cdna");
    $self->cdna_ioh($cdna_ioh);


    return;
}

=head2 padding

  Title   : padding
  Usage   : $self->padding()
  Function: get/sets of the padding on each side of sequence 
            to pad before passing to est2genome 
  Returns :  
  Args    :

=cut

sub padding{
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_padding'} = $arg;
    }
    return $self->{'_padding'};
}

=head2 genome_ioh

  Title   : genome_ioh
  Usage   : $self->genome_ioh()
  Function: get/set of the iohandler id for fetching the genome sequence 
  Returns :
  Args    :

=cut

sub genome_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_genome_ioh'} = $arg;
    }
    return $self->{'_genome_ioh'};
}

=head2 blast_dir

  Title   : blast_dir
  Usage   : $self->blast_dir()
  Function: get/set of the blast directory 
  Returns :
  Args    :

=cut

sub blast_dir {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_blast_dir'} = $arg;
    }
    return $self->{'_blast_dir'};
}

=head2 cdna_ioh

  Title   : cdna_ioh
  Usage   : $self->cdna_ioh()
  Function: get/set of the iohandler id for fetching the cdna  sequence
  Returns :
  Args    :

=cut

sub cdna_ioh {
    my ($self,$arg) = @_;
    if($arg){
        $self->{'_cdna_ioh'} = $arg;
    }
    return $self->{'_cdna_ioh'};
}

=head2 datatypes

  Title   : datatypes
  Usage   : $self->datatypes()
  Function: get/set of the datatypes required for this input create
  Returns :
  Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt = Bio::Pipeline::DataType->new('-object_type'=>'Bio::SeqFeatureI',
                                          '-name'=>'sequence',
                                          '-reftype'=>'ARRAY');

    my %dts;
    $dts{input} = $dt;
    return %dts;
}

sub _parse_top_hits {
    my ($self,$file) = @_;
    my $sio = Bio::SearchIO->new(-file=>$file,-format=>"blast");
    my @id;
    my $count = 1;
RESULT:    while (my $r= $sio->next_result){
      while (my $hi = $r->next_hit){
       while(my $hs = $hi->next_hsp){
           push @id, [$hs->query->seq_id,$hs->subject->seq_id];
    #       return \@id if $count > 5;
     #      $count++;
           next RESULT;
       }
      }
    }
RETURN:    return \@id;
}
=head2 run

  Title   : run
  Usage   : $self->run($next_anal,$input)
  Function: creates the jobs for est2genome 
  Returns :
  Args    : L<Bio::Pipeline::Analysis>, Hash reference

=cut

sub run {
    my ($self,$next_anal,$infile) = @_;
    my $infile = $self->infile ||$self->throw("Need an input file");
    my $cdna_ioh = $self->cdna_ioh   || $self->throw("Need a cdna iohandler");
    my $genome_ioh = $self->genome_ioh   || $self->throw("Need a genome iohandler");

    #my $total = Bio::Root::IO->catfile($blast_dir,'blast_report'.time().rand(1000));
    #system("echo $blast_dir/* | xargs cat > $total");
    my @hits = @{$self->_parse_top_hits($infile)};
   
    foreach my $hit(@hits){
      my $in1 = Bio::Pipeline::Input->new(-name=>$hit->[0],-tag=>"cdna",-input_handler=>$cdna_ioh);
      my $in2 = Bio::Pipeline::Input->new(-name=>$hit->[1],-tag=>"genome",-input_handler=>$genome_ioh);
      my $job = $self->create_job($next_anal,[$in1,$in2]);
      $self->dbadaptor->get_JobAdaptor->store($job);
    }

    return 1;
    
}

1;
    



