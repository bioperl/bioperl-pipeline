#
# BioPerl module for Bio::Pipeline::Utils::Converter
#
# Cared for by Juguang Xiao  <juguang@fugu-sg.org> ,Kiran <kiran@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME

Bio::Pipeline::Utils::Converter object

The converter object for handling object conversion during io handling.

=head1 SYNOPSIS

  use Bio::Pipeline::Utils::Converter;

  # an EnsEMBL analysis and raw contig objects are needed 
  # when converting to EnsEMBL feature objects.
  
  my $ens_analysis; # a Bio::EnsEMBL::Analysis object
  my $ens_contig; # a Bio::EnsEMBL:RawContig object
  
  my @objs; # an array of original objects.
  
  my $converter = new Bio::Pipeline::Utils::Converter(
        -in => 'Bio::Search::Hit::GenericHit',
        -out => 'Bio::EnsEMBL::DnaPepAlignFeature',
        -analysis => $ens_analysis,
        -contig => $ens_contig
    }
  
  # NOTE: Convensions, that convert method accepts an array ref 
  # and returns an array ref.
  
  my @converted_obj = @{$conveter->convert(\@objs)};

=head1 DESCRIPTION

  A converter factory. Currently we implemented the conversions between:
    1. Bio::Search::Hit::GenericHit -> Bio::EnsEMBL::BaseAlignFeature
    2. Bio::SeqFeature::Generic -> Bio::EnsEMBL::SeqFeature, SimpleFeature
    3. Bio::SeqFeature::FeaturePair -> Bio::EnsEMBL::FeaturePair

=head1 FEEDBACK

=head2 Mailing Lists

User feedback is an integral part of the evolution of this and other
Bioperl modules. Send your comments and suggestions preferably to one
of the Bioperl mailing lists.  Your participation is much appreciated.

  bioperl-l@bioperl.org          - General discussion
  http://bio.perl.org/MailList.html             - About the mailing lists

=head2 Reporting Bugs

Report bugs to the Bioperl bug tracking system to help us keep track
the bugs and their resolution.  Bug reports can be submitted via email
or the web:

  bioperl-bugs@bio.perl.org
  http://bugzilla.bioperl.org/

=head1 AUTHOR - Juguang, Kiran

Xiao Juguang <juguang@fugu-sg.org>
Kiran <kiran@fugu-sg.org>

=head1 APPENDIX

The rest of the documentation details each of the object methods. 
Internal methods are usually preceded with a _

=cut


package Bio::Pipeline::Utils::Converter;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


=head2 new

  Title   : new
  Usage   : my $converter = Bio::Pipeline::Utils::Converter->new(
                '-module'=>'Bio::SeqFeatureIO',
                '-method'=>"convert",
                '-rank'  => 1
            );
  Function: constructor for converter object
  Returns : L<Bio::Pipeline::Utils::Converter>
  Args    : module the module name
            method the method to call that converts the object
            rank   the rank of the converter assuming that they may be
                   more than one converter

=cut

sub new {
    my($caller, @args) = @_;
    my $class = ref($caller) || $caller;
    
    if($class =~ /Bio::Pipeline::Utils::Converter::(\S+)/){
        my ($self) = $class->SUPER::new(@args);
        $self->_initialize(@args);
        return $self;
    }else{
        my %params = @args;
        @params{map {lc $_} keys %params} = values %params; 

        my $instance = $class->_parse_instance($params{-in}, $params{-out});

        return undef unless($class->_load_module($instance));
        return "$instance"->new(@args);
    }   
}

=head2 _parse_instance


  Return  : a full package name
=cut 

sub _parse_instance {
    my ($self, $in, $out) = @_;
    if($out =~ /^Bio::EnsEMBL::(\S+)/){
        return 'Bio::Pipeline::Utils::Converter::BaseEnsEMBLConverter';
    }else{
        $self->throw("[$in] to [$out], not supported");
    }
}

sub _initialize{
	my ($self) = @_;
	return;
}

=head2 convert

  Title   : convert
  Usage   : my $obj = $conv->convert($obj);
  Function: does the actual conversion
  Returns : whatever object it is supposed to convert to
  Args    : the input object to convert

=cut

sub convert {
	 my ($self, $input) = @_;

	 $input || $self->throw("Need a ref of array of input objects to convert");
    unless(ref($input) eq "ARRAY"){
        return $self->_convert_single($input);
        $self->warn("The input of convert is supposed to be a ref of array");
    }

    my @outputs = ();
    foreach(@{$input}){
        my $output = $self->_convert_single($_);
        push @outputs, $output;
    }
    
    return \@outputs;
}

sub _convert_single{
    my ($self) = @_;
    $self->throw("Not implemented. Please check the instance subclass.");
    
}

=head2 _create_obj

  Title   : _create_obj
  Usage   : my $obj = $conv->_create_obj($obj);
  Function: loads the object 
  Returns : whatever object it is supposed to create
  Args    :  the module name

=cut

sub _create_obj {
    my ($self,$module,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $self->_load_module($module);

    my $obj = "${module}"->new(@args);

    return $obj;
}

1;
