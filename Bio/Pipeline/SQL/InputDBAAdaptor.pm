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
                              dba.dbname,
                              dba.driver,
                              dba.host,
                              dba.user,
                              dba.pass,
                              dba.module,
                              inp.input_dba_id,
                              inp.biodbadaptor,
                              inp.biodbname,
                              inp.data_adaptor,
                              inp.data_adaptor_method
                              FROM input_dba inp, dbadaptor dba
                              WHERE inp.input_dba_id = '$id' AND
                              inp.dbadaptor_id = dba.dbadaptor_id"
                              );
    $sth->execute();
    
     my ($dbname,$driver,$host,$user,$pass,$module,$dbID,$biodbadaptor,$biodbname,$data_adaptor,$data_adaptor_method)  = $sth->fetchrow_array;
     ($dbname && $module) || $self->throw("No DBadaptor found.");
     ($data_adaptor && $data_adaptor_method) || $self->throw("No data adaptor or data adaptor method found.");

    my $ioadpt = Bio::Pipeline::IO->new(-dbadaptor_dbname =>$dbname,
                                        -dbadaptor_driver =>$driver,
                                        -dbadaptor_host   =>$host,
                                        -dbadaptor_user   =>$user,
                                        -dbadaptor_pass   =>$pass,
                                        -dbadaptor_module =>$module,
                                        -dbID             =>$dbID,
                                        -biodbadaptor     =>$biodbadaptor,
                                        -biodbname        =>$biodbname,
                                        -data_adaptor     =>$data_adaptor,
                                        -data_adaptor_method  =>$data_adaptor_method);

    $ioadpt->adaptor($self);
                                    
    return $ioadpt;
}


sub fetch_dbIDs_by_analysis_id{
    my ($self,$analysis_id) = @_;

    my $query = "   SELECT input_dba_id 
                    FROM   analysis_input_dba
                    WHERE  analysis_id = ? ";
    my $sth = $self->prepare($query);
    $sth->execute($analysis_id);

    my @dbIDs;

    while (my ($id) = $sth->fetchrow_array){
        push (@dbIDs,$id);
    }

    return @dbIDs;
}

1;


