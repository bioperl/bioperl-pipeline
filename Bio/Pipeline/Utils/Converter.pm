#
# BioPerl module for Bio::Pipeline::Converter
#
# Cared for by Kiran <kiran@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::Converter input object

The converter object for handling object conversion during io handling.

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
  http://bio.perl.org/bioperl-bugs/

=head1 AUTHOR - Kiran 

Email kiran@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::Converter;

use vars qw(@ISA);
use strict;

use Bio::Root::Root;

@ISA = qw(Bio::Root::Root);


sub new {
  my($class,@args) = @_;
  
  my $self = $class->SUPER::new(@args);

  my ($dbID, $module,$method, $rank)  =
      $self->_rearrange([qw(DBID
                            MODULE
			    METHOD 
                            RANK 
                        )],@args);

  $self->dbID($dbID);
  $self->module($module);
  $self->method($method);
  $self->rank($rank);

  return $self;
}

sub convert {
    my ($self, $input) = @_;
    my $obj = $self->_create_obj($self->module);
    my $method = $self->method;
    my $output = $obj->$method($input);
    return $output;
}

sub _create_obj {
    my ($self,$module,@args) = @_;
    $module || $self->throw("Need an object to create object");

    if($module=~/::/){
        $module =~ s/::/\//g;
        require "${module}.pm";
        $module =~s/\//::/g;
    }
    my $obj = "${module}"->new(@args);

    return $obj;
}

sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
            $self->{_dbID} = $arg;
    }

    return $self->{_dbID};
}

 
sub module {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_module} = $arg;
    }

    return $self->{_module};
}

sub method {
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_method} = $arg;
    }

    return $self->{_method};
}

sub rank{
    my ($self,$arg) = @_;

    if (defined($arg)) {
	    $self->{_rank} = $arg;
    }
    return $self->{_rank};
}

1;
