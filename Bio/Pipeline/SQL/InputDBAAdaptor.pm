#
# BioPerl module for Bio::Pipeline::IO
#
# Cared for by Shawn Hoon <shawnh@fugu-sg.org>
#
#
# You may distribute this module under the same terms as perl itself
#
# POD documentation - main docs before the code
#
=head1 NAME
Bio::Pipeline::InputDBAAdaptor input/output object for pipeline

=head1 SYNOPSIS
my $in_adpt = Bio::Pipeline::InputDBAAdaptor->new($db);


=head1 DESCRIPTION

The adaptor to get the input database adaptor 

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

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org 

=head1 APPENDIX

The rest of the documentation details each of the object methods. Internal metho
ds are usually preceded with a _

=cut


package Bio::Pipeline::SQL::InputDBAAdaptor;

use vars qw(@ISA);
use strict;

use Bio::Pipeline::SQL::BaseAdaptor;
use Bio::Pipeline::IO;
@ISA = qw(Bio::Pipeline::SQL::BaseAdaptor);


=head 1 Fetch methods 
These methods retrievs the adaptors

=head2 fetch_by_dbID

  Title    : fetch_by_dbID
  Function : fetches the adaptor to the input adaptor 
  Example  : $in_adpt = $io ->fetch_by_dbID(1)
  Returns  : Bio::Pipeline::IO 
  Args     : a string which specifies the id of the adaptor 

=cut

sub fetch_by_dbID {
    my ($self,$id) = @_;
    $id || $self->throw("Need a db ID");
    
    my $sth = $self->prepare("SELECT 
                              dbadaptor_id,
                              biodbadaptor_method,
                              biodbname,
                              data_adaptor,
                              data_adaptor_method
                              FROM input_dba 
                              WHERE input_dba_id = '$id'"
                              );
    $sth->execute();
    
    my ($dbadaptor_id,$biodbadaptor,$biodbname,$data_adaptor,$data_adaptor_method) = $sth->fetchrow_array;

    #fetch dbadaptor
    my $adaptor;
    if($dbadaptor_id){ 
      $adaptor = $self->_fetch_db_adaptor($dbadaptor_id);
    }
    
    #if biodbadaptor exist, need another layer to get the dbadaptor
    if ($biodbadaptor && $biodbname){
      $adaptor = $adaptor->${biodbadaptor}($biodbname);
    }
    my $ioadpt = Bio::Pipeline::IO->new(-dbadaptor=>$adaptor,
                                        -dataadaptor=>$data_adaptor,
                                        -dataadaptormethod=>$data_adaptor_method);

    return $ioadpt;
}

sub _fetch_db_adaptor {
    my ($self,$id) = @_;
    my $sth = $self->prepare("SELECT dbname,driver,host,user,pass,module 
                              FROM dbadaptor
                              WHERE dbadaptor_id = $id");
    $sth->execute();
    my ($dbname,$driver,$host,$user,$pass,$module) = $sth->fetchrow_array();
    if($module =~/::/)  {
         $module =~ s/::/\//g;
         require "${module}.pm";
         $module =~s/\//::/g;
     }
    my $db_adaptor = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass);

    return $db_adaptor;
}


1;


