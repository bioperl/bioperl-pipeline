# Please direct questions and support issues to <bioperl-l@bioperl.org> 
#
# Cared for by Chuah Aaron <aaron@tll.org.sg>
#
# Copyright Chuah Aaron
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod

=head1 NAME

Bio::Pipeline::Runnable::Promoterwise

=head1 SYNOPSIS

=head1 DESCRIPTION

This package is based on Promoterwise.  Promoterwise takes in two
fasta files.  The resulting output is parsed to produce a set of
Bio::SeqFeatures.

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Support 
 
Please direct usage questions or support issues to the mailing list:
  
L<bioperl-l@bioperl.org>
  
rather than to the module maintainer directly. Many experienced and 
reponsive experts will be able look at the problem and quickly 
address it. Please include a thorough description of the problem 
with code and data examples if at all possible.

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution. Bug reports can be submitted via email
    or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR -Chuah Aaron

Email aaron@tll.org.sg

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Runnable::Promoterwise;
use vars qw(@ISA);
use strict;
use Bio::Root::RootI;
use Bio::Pipeline::DataType;
use Bio::Tools::Run::Promoterwise;
use Bio::Pipeline::RunnableI;

@ISA = qw(Bio::Pipeline::RunnableI);


sub new {
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);    
    return $self;
}

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');
    my $dt2 = Bio::Pipeline::DataType->new(-object_type=>'Bio::SeqI');

    my %dt;
    $dt{subject_dna} = $dt1;
    $dt{query_dna} = $dt2;
    return %dt;
}


sub subject_dna {
    my ($self, $seq) = @_;
    if ($seq)
    {
        unless ($seq->isa("Bio::PrimarySeqI") || $seq->isa("Bio::SeqI")) {
            print "subject $seq is not a sequence object!! Trying to read it as a filename\n";
            my $subject_file=Bio::Root::IO->catfile($seq);
            my $subject_seqs=Bio::SeqIO->new(-file=>$subject_file, -format=>'fasta');
            $seq=$subject_seqs->next_seq() || $self->throw("Subject dna isn't a Bio::Seq or Bio::PrimarySeq or fasta file");
        }
        $self->{'_subject_dna'} = $seq ;
    }
    return $self->{'_subject_dna'};
}

sub target_dna {
    my ($self, $seq) = @_;
    if ($seq)
    {
        unless ($seq->isa("Bio::PrimarySeqI") || $seq->isa("Bio::SeqI")) {
            print "target $seq is not a sequence object!! Trying to read it as a filename\n";
            my $target_file=Bio::Root::IO->catfile($seq);
            my $target_seqs=Bio::SeqIO->new(-file=>$target_file, -format=>'fasta');
            $seq=$target_seqs->next_seq() || $self->throw("Target dna isn't a Bio::Seq or Bio::PrimarySeq or fasta file");
        }
        $self->{'_target_dna'} = $seq ;
    }
    return $self->{'_target_dna'};
}


=head2 run

    Title   :  run
    Usage   :   $obj->run()
    Function:   Runs promoterwise and creates array of seqfeature::featurepairs
    Returns :   
    Args    :   none

=cut

sub run {

    my ($self) = @_;
     #check seq
    my $analysis = $self->analysis;
    $self->throw("Analysis not set")
        unless $analysis->isa("Bio::Pipeline::Analysis");
    my $seq1 = $self->subject_dna() ||
        $self->throw("Subject dna sequence required for Promoterwise\n");
    my $seq2 = $self->target_dna() ||
        $self->throw("Target dna sequence required for Promoterwise\n");
    #run promoterwise
    my @params = $self->parse_params($self->analysis->analysis_parameters);
    my $factory = Bio::Tools::Run::Promoterwise->new(@params);
    $factory->executable($analysis->program_file) if $analysis->program_file;

    my @promoters;
    eval {
      @promoters = $factory->run($seq1, $seq2);
    };
    $self->output(\@promoters);
    return \@promoters;
 }

=head2 output

  Title   :   output
  Usage   :   $self->output($seq)
  Function:   Get/set method for output
  Returns :   An array of Bio::SeqFeature objects
  Args    :   An array ref to an array of Bio::SeqFeature objects

=cut

sub output{
    my ($self,$promoter) = @_;
    if(defined $promoter){
      (ref($promoter) eq "ARRAY") ||
          $self->throw("Output must be an array reference.");
      $self->{'_promoter'} = $promoter;
    }
    return @{$self->{'_promoter'}};
}

1;
