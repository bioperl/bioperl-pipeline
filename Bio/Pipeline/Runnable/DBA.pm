# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
# Copyright Shawn Hoon 
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code

=pod 

=head1 NAME

 Bio::Pipeline::Runnable::DBA

=head1 SYNOPSIS

=head1 DESCRIPTION
Runnable for Dna Block Aligner program by Ewan Birney available at
ftp://ftp.sanger.ac.uk/pub/birney/wise2/

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bio.perl.org

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution. Bug reports can be submitted via email
    or the web:

  bioperl-bugs@bio.perl.org
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Shawn Hoon 

Email shawnh@fugu-sg.org 

Describe contact details here

=head1 APPENDIX

The rest of the documentation details each of the object methods.
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Runnable::DBA;
use vars qw(@ISA);
use strict;
use FileHandle;
use Bio::PrimarySeq; 
use Bio::SeqFeature::FeaturePair;
use Bio::SeqFeature::Generic;
use Bio::SeqI;
use Bio::SeqIO;
use Bio::Root::Root;
use Bio::Pipeline::DataType;
use Bio::Pipeline::RunnableI;
use Bio::Tools::Run::Alignment::DBA;

@ISA = qw(Bio::Pipeline::RunnableI);

sub new {
  my ($class, @args) = @_;
  my $self = $class->SUPER::new(@args);
  return $self;

}

=head2 datatypes

Title   :   datatypes 
Usage   :   $self->datatypes
Function:   Returns the datatypes that the runnable requires. This is used by the Runnable DB to 
            match the inputs to the corresponding. 
Returns :   It returns a hash of the different data types. The key of the hash is the name of the 
            get/set method used by the RunnableDB to set the input
Args    :

=cut

sub datatypes {
    my ($self) = @_;
    my $dt1 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my $dt2 = Bio::Pipeline::DataType->new('-object_type'=>'Bio::PrimarySeqI',
                                           '-name'=>'sequence',
                                           '-reftype'=>'SCALAR');
    my %dts;
    $dts{feat1} = $dt1;
    $dts{feat2} = $dt2;

    return %dts; 
}

=head2 feat1
  
Title   :   feat1
Usage   :   $self->feat1($seq)
Function:   
Returns :   
Args    :   

=cut

sub feat1{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat1'} = $feat;
    }
    return $self->{'_feat1'};
}

=head2 feat2
  
Title   :   feat2
Usage   :   $self->feat2($seq)
Function:   
Returns :   
Args    :   

=cut

sub feat2{
    my ($self,$feat) = @_;
    if (defined($feat)){
        $self->{'_feat2'} = $feat;
    }
    return $self->{'_feat2'};
}

=head2 dba
  
Title   :   dba
Usage   :   $self->dba($seq)
Function:   Get/set method for dba 
Returns :   String 
Args    :   String 

=cut

sub dba{
    my ($self,$dba) = @_;
    if (defined($dba)){
        $self->{'_dba'} = $dba;
    }
    return $self->{'_dba'};
}


=head2 run
  
Title   :   run
Usage   :   $self->run($seq)
Function:   Runs DBA 
Returns :   
Args    :  

=cut

sub run {
  my ($self) = @_;
  my @seq = ($self->feat1,$self->feat2);
  my $params = $self->params;
  my $dba = $self->dba;

  $self->throw("Analysis not set") unless $self->analysis->isa("Bio::Pipeline::Analysis");
  my $factory;
  if($self->analysis->parameters){
    my @params = $self->parse_params($self->analysis->parameters);
    $factory = Bio::Tools::Run::Alignment::DBA->new(@params);
  }
  else {
    $factory = Bio::Tools::Run::Alignment::DBA->new();
  }

  my @hsps;
  eval {
    @hsps = $factory->align(\@seq);
  };
  $self->output(\@hsps);
  return \@hsps;

}

=head2 output
  
Title   :   output
Usage   :   $self->output($seq)
Function:   Get/set method for output 
Returns :   An array of Bio::Search::HSP::GenericHSP objects 
Args    :   An array ref to an array of Bio::Search::HSP::GenericHSP objects

=cut

sub output{
    my ($self,$hsp) = @_;
    if(defined $hsp){
      (ref($hsp) eq "ARRAY") || $self->throw("Output must be an array reference.");
      $self->{'_hsp'} = $hsp;
    }
    return @{$self->{'_hsp'}};
}

1;  





















    
