#
# BioPerl module for Bio::Pipeline::Utils::Dumper::generic
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

Bio::Pipeline::Dumper::blastscore

=head1 SYNOPSIS

  use Bio::TreeIO;
  use Bio::Pipeline::Dumper;

  my $tio = Bio::TreeIO->new(-file=>$ARGV[0],-format=>"newick");

  while(my $tree =$tio->next_tree){
    push @tree, $tree;
  }

  my $du = Bio::Pipeline::Dumper->new(-module=>"generic",
                                      -format=>"newick",
                                       -dir=>"/usr/users/shawnh/src/bioperl-pipeline/Bio/Pipeline/Dumper",
                                       -file_suffix=>".cls",
                                       -prefix=>"shawn");

  $du->dump(\@tree);

=head1 DESCRIPTION

A wrapper for the various bioperl IO modules for dumping objects to file. 
Basically allows input of objects as array ref and loops through writing to file.


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

package Bio::Pipeline::Utils::Dumper::generic;
use vars qw(@ISA @BS_PARAMS %OK_FIELD $AUTOLOAD);
use strict;
use Bio::Root::Root;
use Bio::Pipeline::Utils::Dumper;

@ISA = qw(Bio::Pipeline::Utils::Dumper);

sub _initialize {
  my($self,@args) = @_;
  $self->SUPER::_initialize(@args);
  my ($format) = $self->_rearrange([qw(FORMAT)],@args);
  $self->format($format);

}

=head2 format

  Title   : format
  Usage   : $self->format($format)
  Function: get/set for the format to pass to IO module 
  Returns : string
  Args    : a string specifying the format

=cut

sub format {
  my ($self,$val) = @_;
  if($val) {
    $self->{'_format'} = $val;
  }
  return $self->{'_format'};
}

=head2 dump 

  Title   : dump 
  Usage   : $dumper->dump(@hit);
  Function: dumps the various bioperl objects to file 
  Returns :  
  Args    : an array of bioperl objects 

=cut

sub dump {
    my ($self,$obj) = @_;

    $obj || return;

    my @obj =  ref($obj) eq "ARRAY" ? @{$obj} : ($obj);

    my ($io,$method) = $self->_get_io_module($obj[0],$self->format);
    if(ref($io) eq "GLOB"){#just a file handle
      foreach my $obj(@obj){
        print $io $obj->$method."\n";
        #print sub features if exist
        if($obj->can('sub_SeqFeature') && $obj->sub_SeqFeature){
            foreach my $sub($obj->sub_SeqFeature){
                print $io $sub->$method."\n";
            }
        }
      }
    }
    else {
      foreach my $obj(@obj){
        $io->$method($obj);
      }
    }

    return $self->file; 

}

sub _get_io_module {
    my ($self,$obj,$format) = @_;
    if($obj->isa("Bio::Tree::TreeI")){
        $self->_load_module("Bio::TreeIO");
        return (Bio::TreeIO->new(-file=>$self->file,-format=>$format),"write_tree");
    }
    elsif($obj->isa("Bio::Align::AlignI")){
        $self->_load_module("Bio::AlignIO");
        return (Bio::AlignIO->new(-file=>$self->file,-format=>$format),"write_aln");
    }
    elsif($obj->isa("Bio::PrimarySeqI")){
        $self->_load_module("Bio::SeqIO");
        return (Bio::SeqIO->new(-file=>$self->file,-format=>$format),"write_seq");
    }
    elsif($obj->isa("Bio::Map::MapI")){
        $self->_load_module("Bio::MapIO");
        return (Bio::MapIO->new(-file=>$self->file,-format=>$format),"write_map");
    }
    elsif($obj->isa("Bio::Search::Result::ResultI")){
        $self->_load_module("Bio::SearchIO");
        return (Bio::SearchIO->new(-file=>$self->file,-format=>$format),"write_result");
    }
    elsif($obj->isa("Bio::Matrix::PhylipDist")){
        open (FILE, $self->file);
        return (\*FILE, "print_matrix");
    }
    elsif($obj->isa("Bio::SeqFeatureI")){
        open(FILE, $self->file);
        return(\*FILE,"gff_string");
    }
    else {
        $self->throw(ref $obj. " cannot be dumped through this module");
    }
}
        
1;
