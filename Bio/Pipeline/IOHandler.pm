#
# BioPerl module for Bio::Pipeline::IOHandler
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

Bio::Pipeline::IOHandler input/output object for pipeline

=head1 SYNOPSIS

  ##################
  #input fetching
  ##################

  #Fetching from database

  my $data_handler1 = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                      -method=>"get_ContigAdaptor",
                                                      -rank=>1);
  my $data_handler2 = Bio::Pipeline::DataHandler->new(-dbid=>2,
                                                      -method=>"fetch_by_dbID",
                                                      -argument=>['INPUT'],
                                                      -rank=>2);

  my $io_db = Bio::Pipeline::IOHandler->new_ioh_db(-dbID=>1,
                                                   -type=>'INPUT',
                                                   -dbadaptor_dbname=>"ensembl-db",
                                                   -dbadaptor_driver=>"mysql",
                                                   -dbadaptor_host  =>"localhost",
                                                   -dbadaptor_user  => "root",
                                                   -dbadpator_pass  => "",
                                                   -dbadaptor_module=> "Bio::EnsEMBL::DBSQL::DBAdaptor",
                                                   -dbadaptor_port  =>3306,
                                                   -datahandlers    => [$datahandler_1,$datahandler_2]);

  my $in = Bio::Pipeline::Input->new(-name=>"Sequence1",
                                     -tag =>"input",
                                     -job_id=>1);
  my $input = $io_db->fetch_input($in); #$input is an array of ref ensembl contigs

  print $input->seq;

  #alternatively you can use any modules to read, here we are reading from a database
  #of fasta formatted files

  my $data_handler1 = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                      -method=>"new",
                                                      -rank=>1);
  my $data_handler2 = Bio::Pipeline::DataHandler->new(-dbid=>2,
                                                      -method=>"fetch_by_Seq_id",
                                                      -argument=>['INPUT'],
                                                      -rank=>2);
  my $io_stream =  Bio::Pipeline::IOHandler->new_io_stream(-dbID=>1,
                                                           -type=>'INPUT',
                                                           -module=>'Bio::DB::Fasta',
                                                           -datahandlers=>[$datahandler_1,$datahandler_2]);
  my $in = Bio::Pipeline::Input->new(-name=>"sequence_1",
                                     -tag =>"input",
                                     -job_id=>1);
  my $seq = $io_stream->fetch_input($in);

  print $seq->seq;

  ################## 
  #Writing to output
  ##################  

   my $data_handler1 = Bio::Pipeline::DataHandler->new(-dbid=>1,
                                                      -method=>"get_FeatureAdaptor",
                                                      -rank=>1);
   my $data_handler2 = Bio::Pipeline::DataHandler->new(-dbid=>2,
                                                      -method=>"store",
                                                      -argument=>['OUTPUT'],
                                                      -rank=>2);

   my $io_db = Bio::Pipeline::IOHandler->new_ioh_db(-dbID=>1,
                                                   -type=>'INPUT',
                                                   -dbadaptor_dbname=>"ensembl-db",
                                                   -dbadaptor_driver=>"mysql",
                                                   -dbadaptor_host  =>"localhost",
                                                   -dbadaptor_user  => "root",
                                                   -dbadpator_pass  => "",
                                                   -dbadaptor_module=> "Bio::EnsEMBL::DBSQL::DBAdaptor",
                                                   -dbadaptor_port  =>3306,
                                                   -datahandlers    => [$datahandler_1,$datahandler_2]);
    my @features = $runnable->output;

    $io_db->write_output(-output=>@features);


=head1 DESCRIPTION

The input/output handler for reading input and writing output.
IOHandler object represents a series of method calls that are needed
to fetch a particular input or store outputs.

It represents the following snippet of code in the database:

  my $db = Bio::EnsEMBL::DBSQL::DBAdaptor->new(-dbname=>"my_db",
                                               -user  =>"root");
  my $gene = $db->get_GeneAdaptor->fetch_by_dbID(1);

Methods are represented by DataHandler objects which in term have
argument objects. Datahandlers are rank in the order that they are
cascaded, likewise for arguments.

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
  http://bugzilla.open-bio.org/

=head1 AUTHOR - Shawn Hoon

Email shawnh@fugu-sg.org

=head1 APPENDIX

The rest of the documentation details each of the object
methods. Internal metho ds are usually preceded with a _

=cut

package Bio::Pipeline::IOHandler;
use vars qw(@ISA);
use strict;

use Bio::Root::Root;
use Bio::Pipeline::PipeConf qw(RELEASE_DBCONNECTION);

@ISA = qw(Bio::Root::Root);

=head1 Constructors

=head2 new_ioh_db

  Title   : new_ioh_db
  Usage   : my $io_db = Bio::Pipeline::IOHandler->new_ioh_db(-dbID=>1,
                                                   -type=>'INPUT',
                                                   -dbadaptor_dbname=>"ensembl-db",
                                                   -dbadaptor_driver=>"mysql",
                                                   -dbadaptor_host  =>"localhost",
                                                   -dbadaptor_user  => "root",
                                                   -dbadpator_pass  => "",
                                                   -dbadaptor_module=> "Bio::EnsEMBL::DBSQL::DBAdaptor",
                                                   -dbadaptor_port  =>3306,
                                                   -datahandlers    => [$datahandler_1,$datahandler_2]); 
  Function: generates a new Bio::Pipeline::IOHandler for DB connections
  Returns : a new IOHandler object 
  Args    : dbID              the dbID of this iohandler
            type              iohandler type (INPUT|OUTPUT)
            dbadaptor_dbname  the database name (required)
            dbadaptor_driver  the database driver
            dbadaptor_host    the database host name
            dbadaptor_user    the database user
            dbadaptor_pass    the database password
            dbadaptor_module  the module used for connecting to the database
            dbadaptor_port    the database port number
            datahandlers      the array ref of datahandler objects
            analysis          a Bio::Pipeline::Analysis object(optional)

=cut

sub new_ioh_db {
  my($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$type,$dbadaptor_dbname,$dbadaptor_driver,$dbadaptor_host,
      $dbadaptor_user,$dbadaptor_pass,$dbadaptor_module,$dbadaptor_port,
      $datahandlers,$analysis) = $self->_rearrange([ qw( DBID
                                               TYPE
                                                DBADAPTOR_DBNAME
                                                DBADAPTOR_DRIVER
                                                DBADAPTOR_HOST
                                                DBADAPTOR_USER
                                                DBADAPTOR_PASS
                                                DBADAPTOR_MODULE
                                                DBADAPTOR_PORT
                                                DATAHANDLERS
                                                ANALYSIS)],@args);

  $dbadaptor_dbname ||= $self->throw("Need a dbadaptor name");
  $dbadaptor_driver ||= "mysql";
  $dbadaptor_user   ||= "root";
  $dbadaptor_host   ||= "localhost";
  $dbadaptor_pass   ||= "";
  $dbadaptor_port   ||= "";
  $dbadaptor_module || $self->throw("Need a module for db adaptor");
  $datahandlers     || $self->throw("Need datahandlers in IOHandler constructor");

  $self->dbID($dbID);
  $self->dbadaptor_dbname($dbadaptor_dbname);
  $self->dbadaptor_driver($dbadaptor_driver);
  $self->dbadaptor_host($dbadaptor_host);
  $self->dbadaptor_user($dbadaptor_user);
  $self->dbadaptor_pass($dbadaptor_pass);
  $self->dbadaptor_port($dbadaptor_port);
  $self->dbadaptor_module($dbadaptor_module);
  $self->adaptor_type("DB");
  $self->type($type);
  $self->{'_datahandlers'} = $datahandlers; 
  
  return $self;
}    


=head2 new_ioh_stream

  Title   : new_ioh_stream
  Usage   : my $io_stream =  Bio::Pipeline::IOHandler->new_io_stream(-dbID=>1,
                                                                     -type=>'INPUT',
                                                                     -module=>'Bio::DB::Fasta',
                                                                     -datahandlers=>[$datahandler_1,$datahandler_2]);
  Function: generates a new Bio::Pipeline::IOHandler for streams(files or remote fetching) 
  Returns : a new IOHandler object 
  Args    : dbID        - the database id of the module
            type        -iohandler type (INPUT|OUTPUT)
            module      -a string of the form Bio::XXX  that specifies the stream adaptor module
            file_path   -a directory path for stream adaptor which have files as input names
            file_suffix -the file extenstion to append to a file input name
            datahandlers - array ref of L<Bio::Pipeline::DataHandler>

Note on file paths and file suffix

File paths and file_suffix are optional parameters. They are used in
conjunction with input names when fetching using streamadaptors where
file paths are inputs. When an iohandler-E<gt>fetch_input is called,
the special argument tag INPUT is replaced with the input_name
specified in the input table.  If the file_path and file_suffix
arguments are present, the input_name is modified to the following:

  /file_path/input_name.file_suffix

=cut

sub new_ioh_stream{
    my ($class,@args) = @_;
    my $self = $class->SUPER::new(@args);
    my ($dbID,$type,$module,$file_path,$file_suffix,$datahandlers) = $self->_rearrange([qw(DBID
                                                       TYPE
                                                       MODULE
                                                       FILE_PATH
                                                       FILE_SUFFIX
                                                       DATAHANDLERS)],@args);

    $module  || $self->throw("Need a stream module");
    $file_path && $self->file_path($file_path);
    $file_suffix && $self->file_suffix($file_suffix); 
    $self->dbID($dbID);
    $self->stream_module($module);

    $self->adaptor_type("STREAM");
    $self->type($type);
    $self->{'_datahandlers'} = $datahandlers;

    return $self;
} 

=head2 new_ioh_chain

  Title   : new_ioh_chain
  Usage   : my $io_chain =  Bio::Pipeline::IOHandler->new_io_chain(-dbID=>1,
                                                                    -type=>'INPUT');
                                                                     
  Function: generates a new Bio::Pipeline::IOHandler for chain output from one analysis to another in memory
  Returns : a new IOHandler object 
  Args    : dbID        - the database id of the module
            type        -iohandler type (INPUT|OUTPUT)

=cut

sub new_ioh_chain {

  my ($class,@args) = @_;
  my $self = $class->SUPER::new(@args);
  my ($dbID,$type) = $self->_rearrange([qw(DBID
                                           TYPE
                                          )],@args);
  $self->dbID($dbID);
  $self->adaptor_type("CHAIN");
  $self->type($type);

  return $self;
}
                                                    
=head1 Fetch/Write methods 
These methods calls adaptors to fetch and write inputs and outputs to database
=cut

=head2 fetch_input 

  Title    : fetch_input
  Function : fetches the input(s) from the adaptors supplied 
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : a array ref to the inputs 
  Args     : a string/array ref of strings which specifies the id of the input 

=cut

sub fetch_input {
    my ($self,$input,$not_transformed) = @_;
    my $fetched_input =  $self->_fetch($input);
    if($self->transformers && !$not_transformed){
      $fetched_input = $self->run_transformers('-object'=>$fetched_input,'-format'=>"_format_input_arguments");
    }
    return $fetched_input;
}

sub _fetch {
    my ($self,$input) = @_;
    $input || $self->throw("Need a input object");
    my $input_name = $input->name;

    #hash up the dynamic arguments by datahandler id
    my %dyn_arg;

    if($input->dynamic_arguments){
        foreach my $arg (@{$input->dynamic_arguments}){
            defined $arg->dhID || $self->throw("dynamic arguments much have a datahandler id");
            push @{$dyn_arg{$arg->dhID}},$arg;
        }
    }

    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;

    my $obj; 

    #create the handler fetcher differently depending on whether its a DB or a Stream
    #add the file paths and extension if present
    $input_name = Bio::Root::IO->catfile($self->file_path,$input_name) if $self->file_path;
    $input_name = $input_name.$self->file_suffix if $self->file_suffix;

    if($self->adaptor_type eq "DB"){
        $obj = $self->_load_dbadaptor();
    }
    else {
        my $constructor = shift @datahandlers;
        my @arguments = sort{$a->rank <=> $b->rank} @{$constructor->argument};

        #format the arguments into an array
        my @args = $self->_format_input_arguments($input_name,@arguments);
    
        #load the object
        $obj = $self->_load_obj($self->stream_module,$constructor->method,@args);
    }

    #now call the cascade of datahandler methods
    my $tmp = $obj;
    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @dyn_arg;

        if(ref($dyn_arg{$datahandler->dbID}) eq "ARRAY"){
          @dyn_arg = @{$dyn_arg{$datahandler->dbID}};
        }

        if($#dyn_arg > 0){
          #merge arguments if dynamic arguments exist
          @arguments = $self->_merge_args(\@arguments,\@dyn_arg);
        }

        my @args = $self->_format_input_arguments($input_name,@arguments);
        my $tmp1 = $datahandler->method;
        my @obj = $obj->$tmp1(@args);

        #intermediate objects should return only one object while fetched inputs
        #tend to be in an array
        if(scalar(@obj) == 1){
          $obj = $obj[0];
        }
        else {
          $obj = \@obj;
        }
    }

    #destroy handle only if its a dbhandle
    if($self->adaptor_type eq "DB" && $RELEASE_DBCONNECTION) {
      $tmp->DESTROY;
    };
    
  return $obj;
}

sub run_transformers {
  my ($self,@args) = @_;
  my ($input,$obj,$format) = $self->_rearrange([qw(INPUT OBJECT FORMAT)],@args);
  $obj || $self->throw("Need an object to transform");
  $format || $self->throw("Need an method to format arguments");
  
  if(defined $self->transformers){
      my @trans = sort {$a->rank <=> $b->rank} @{$self->transformers};
      my @new_trans;
      #set the arguments for transformers
      foreach my $t(@trans){
        my $tmp_transformer = Bio::Pipeline::Transformer->new(-module=>$t->module,
                                                              -dbID=>$t->dbID,
                                                              -rank=>$t->rank);

        my @methods = @{$t->method};
        my @new_method;
        foreach my $method(@methods){
            my @arguments = @{$method->arguments};
            my @args;
            if($input){
              @args = $self->$format($input,$obj,@arguments); 
            }
            else {
              @args = $self->$format($obj,@arguments); 
            } 
            my $new_meth = Bio::Pipeline::Method->new(-dbID=>$method->dbID,
                                                     -name=>$method->name,
                                                      -argument=>\@args,
                                                      -rank=>$method->rank);
            push @new_method, $new_meth;

        }
        $tmp_transformer->method(\@new_method);
        push @new_trans, $tmp_transformer;
      }
      
      my $tran = shift @new_trans;
      $obj = $tran->run($obj);
      foreach my $tran(@new_trans){
        if(defined $tran){
          my @obj = $tran->run($obj);
          if(scalar(@obj) == 1){
            $obj = $obj[0];
          }
          else {
            $obj = \@obj;
          }
        }
      }
    }
    return $obj;
}

=head2 _merge_args

  Title    : _merge_args
  Function : merges dynamic arguments with static arguments using rank  
  Example  : $contig = $io ->fetch_input("Scaffold_1");
  Returns  : a array ref to the inputs
  Args     : a string/array ref of strings which specifies the id of the input

=cut

sub _merge_args {
    my ($self,$arg,$dyn) = @_;
    my @final;
    foreach my $static(@{$arg}){
        $final[$static->rank] = $static;
    }
    my @copy = @{$dyn};
    foreach my $dynamic (@{$dyn}){
        for (my $i = 1; $i <=$#final; $i++){
          if(!defined $final[$i]){
              $final[$i] = $dynamic;
              shift @copy;
              last;
         }
       }
    }
    if($#copy > 0){
      push @final, @copy;
    }
    #skip first element
    shift @final;

  return @final;
}

=head2 file_path

 Title   :   file_path
 Usage   :   $self->file_path()
 Function:   get/set
             holds the file_path 
 Returns :   a string
 Args    :   a string (optional)

=cut

sub file_path {
  my ($self,$path) = @_;
  if($path) {
    $self->{'_file_path'} = $path;
  }
  return $self->{'_file_path'};
}

=head2 file_suffix

 Title   :   file_suffix
 Usage   :   $self->file_suffix()
 Function:   get/set
             holds the file extension of the input file.
             it provides the dot if not provided
 Returns :   a string
 Args    :   a string (optional)

=cut

sub file_suffix{
    my ($self,$val) = @_;
    if($val){
        $val = $val=~/^\.\S*/ ? $val : ".$val";
        $self->{'_file_suffix'} = $val;
    }
    return $self->{'_file_suffix'};                         
}  

=head2 _format_input_arguments

  Title    : _format_input_arguments
  Function : formats the arguments for input, replace key word
             INPUT with the input id 
  Example  : $io ->_format_input_arguments($input_id,@args);
  Returns  : an array of arguments
  Args     : 

=cut

sub _format_input_arguments {
  my ($self,$input_name,@arguments) = @_;
  my @args;
  #check whether its a keyword that is demarcated by !xxx!
  for (my $i = 0; $i <=$#arguments; $i++){
   push @args, $arguments[$i]->tag if $arguments[$i]->tag;
   if($arguments[$i]->value =~/!(\S+)!/){
    my $keyword = $1; 
     $self->throw("Not an Bio::Pipeline::Argument object") unless $arguments[$i]->isa("Bio::Pipeline::Argument");
      if ($keyword eq 'INPUT') {
        push @args, $input_name;
      }
      elsif($keyword=~/IOHANDLER(\d+)/){
        my $ioh = $self->adaptor->fetch_by_dbID($1);
        $ioh || $self->throw("No IOHandler found for tag ".$arguments[$i]->value);
        push @args,$ioh->fetch_input('DUMMY');
      }
      elsif($keyword=~/ANALYSIS(\d+)/){
        my $analysis = $self->adaptor->get_AnalysisAdaptor->fetch_by_dbID($1);
        $analysis || $self->throw("No analysis found for tag".$arguments[$i]->value);
        push @args, $analysis;
      }
      elsif($keyword eq 'ANALYSIS') {
        push @args, $self->analysis;
      }
		
      elsif($keyword eq 'ANALYSIS_NAME'){
        push @args, $self->analysis->logic_name;
      }
      else {
        $self->throw("Key word $keyword not allowed");
      }
  }
   else {
        push @args, $arguments[$i]->value;
   }
  }
  return @args;
}

=head2 write_output

  Title    : write_output 
  Function : writes the output to database using the adaptors supplied 
  Example  : $io ->write_output($gene);
  Returns  : 
  Args     : an object/array ref to objects to be stored 

=cut

sub write_output {
    my ($self,@args ) = @_;

    my ($input,$object) = $self->_rearrange([qw(INPUT
                                                OUTPUT)],@args);


    $object || $self->throw("Need an object to write to database");


    #run transformers before storing 
    if(defined $self->transformers){
      $object = $self->run_transformers('-input'=>$input,'-object'=>$object,'-format'=>"_format_output_args");
    }
    #simply return the outputs if of type Chain
    return @{$object} if $self->adaptor_type =~/CHAIN/;

    # the datahandlers for an output handler works in the same principle as the
    # input datahandlers. please see above
    my @datahandlers= sort {$a->rank <=> $b->rank}$self->datahandlers;
    my $obj;
    if($self->adaptor_type eq "DB"){
        $obj = $self->_load_dbadaptor();
    }
    elsif($self->adaptor_type eq 'STREAM') {
        my $constructor = shift @datahandlers;
        my @arguments = sort{$a->rank <=> $b->rank} @{$constructor->argument};
        my @args = $self->_format_output_args($input,$object,@arguments);
        $obj = $self->_load_obj($self->stream_module,$constructor->method,@args);
    }
    elsif($self->adaptor_type eq 'CHAIN'){
        return $object;
    }
    else {
        $self->throw("Unrecognized adaptor_type ".$self->adaptor_type."in Bio::Pipeline::IOHandler::write_output");
    }
   
    my @output_ids;
    my $output_flag = 0;
    
    foreach my $datahandler (@datahandlers) {
        my @arguments = sort {$a->rank <=> $b->rank} @{$datahandler->argument};
        my @args;
        my $tmp1 = $datahandler->method;
        @args = $self->_format_output_args ($input,$object,@arguments);
        @output_ids = $obj->$tmp1(@args);
        $obj = $output_ids[0];
    }
    return @output_ids;
}

=head2 _format_output_arguments

  Title    : _format_output_arguments
  Function : formats the arguments for output, replace key word
             OUTPUT with the output objects,
             INPUT  with the original input id
             INPUTOBJ with the orignial input object 
  Example  : $io ->_format_output_arguments($input,$ouput,@args);
  Returns  : an array of arguments
  Args     : $input the original input object L<Bio::Pipeline::Input>
             $object the array ref of real bio output objects
             @args the arguments to be passed to the store methods

=cut

sub _format_output_args {
    my ($self,$input,$object,@arguments) = @_;
    my @args;
    my $value;
    for (my $i = 0; $i <=$#arguments; $i++){
      if($arguments[$i]->value =~/!(\S+)!/){
        my $keyword = $1;
         #pass output object
        if ($keyword eq 'OUTPUT'){
          $value = $object
        }
        #pass input id
        elsif($keyword eq 'INPUT'){
         if(scalar(@{$input}) == 1 && $arguments[$i]->type eq 'SCALAR'){
            $value = $input->[0]->name;
          }
         else {
  	      my @names;
	        foreach my $in (@{$input}){
		        push @names, $in->name;
	        }
          $value = \@names;
         }
        }
        elsif($keyword=~/ANALYSIS(\d+)/){
          my $analysis = $self->adaptor->get_AnalysisAdaptor->fetch_by_dbID($1);
          $analysis || $self->throw("No analysis found for tag".$arguments[$i]->value);
          $value =  $analysis;
        }
        #pass input obj
        elsif($keyword eq 'INPUTOBJ'){
	       my @values;
	       foreach my $in (@{$input}){
		      push @values, $in->fetch($in);
	       }
	       $value = \@values;
        }
        #provide tag of the like INPUTOBJ1 INPUTOBJ2
        #where 1 and 2 are ranked by the input dbID 
        elsif($keyword =~/INPUTOBJ(\d+)/){
          my @input = sort {$a->dbID<=>$b->dbID}@{$input};
          my $index = $1;
          $self->throw("Requested input obj out of range") unless ($index >= 0 && $index <= $#input);
          my $in= $input[$index];
          $value=[$in->fetch($in)];
        } 
       #pass the output of the IOHandler without passing any
       #input
        elsif($keyword=~/IOHANDLER(\d+)/){
         my $ioh = $self->adaptor->fetch_by_dbID($1);
         $value = $ioh->fetch_input(Bio::Pipeline::Input->new(-name=>"DUMMY"));
        }
	# get the dbadapter
	elsif($keyword=~/DBADAPTOR(\d+)/){
        	$value=$self->adaptor->fetch_by_dbID($1);
        }
        elsif($keyword eq 'UNTRANSFORMED_INPUTOBJ'){
	        my @values;
	        foreach my $in (@{$input}){
	  	      push @values, $in->fetch($in,1);
	        }
	        $value = \@values;
        }
        elsif($keyword eq 'ANALYSIS'){
        	$value=$self->analysis;
        }	
        else {
            $self->throw("Keyword $keyword not allowed");
        }
     }
      #just pass the value
      else {
        $value = $arguments[$i]->value;
      }
    
      #if there are tags
      if($arguments[$i]->tag){
        if($arguments[$i]->type eq "ARRAY"){
            #if your method expects an array
            if(ref($value) eq "ARRAY"){
              push @args, ($arguments[$i]->tag => @{$value});
            }
            else {
		          push @args, ($arguments[$i]->tag => $value); 
           }
        }
        else {
            push @args, ($arguments[$i]->tag => $value);
        }
      } 
      #no tags needed
      else {
        if($arguments[$i]->type eq "ARRAY"){
          if(ref($value) eq "ARRAY"){
            push @args, @{$value};
          }
          else {
              push @args, $value;
          }
        }
        else {
              push @args, $value;
        }
      }
    }
    return @args;
}


=head1 Member variable access

These methods let you get at and set the member variables

=head2 dbadaptor 

  Title    : dbadaptor 
  Function : returns/sets the dbadaptor object 
  Example  : $io->dbadaptor($db); 
  Returns  : the dbadaptor 
  Args     : optionally, the new dbadaptor 

=cut

sub dbadaptor {
    my ($self) = @_;
    if(!$self->{'_dbadaptor'}){
        $self->{'_dbadaptor'} = $self->_load_dbadaptor;
    }
    return $self->{'_dbadaptor'};
}

=head2 datahandlers 

  Title    : datahandler 
  Function : returns the datahandlers associated with this IOHandler onbject
  Example  : $io->datahandlers(); 
  Returns  : the datahandlers 
  Args     : 

=cut

sub datahandlers {
    my ($self) = @_;
    return ref $self->{'_datahandlers'} eq 'ARRAY' ? @{$self->{'_datahandlers'}} :();
}

=head2 dbadaptor_dbname

  Title    : dbadaptor_dbname
  Function : get/set for dbadaptor name
  Example  : $io->dbadaptor_name($name);
  Returns  : the db name
  Args     : optionally, the new name

=cut

sub dbadaptor_dbname {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_dbname'} = $value;
  }
  return $self->{'_dbadaptor_dbname'};
}

=head2 dbadaptor_driver

  Title    : dbadaptor_driver
  Function : get/set for dbadaptor drivr
  Example  : $io->dbadaptor_driver($driver);
  Returns  : the db driver
  Args     : optionally, the new driver

=cut

sub dbadaptor_driver {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_driver'} = $value;
  }
  return $self->{'_dbadaptor_driver'};
}

=head2 dbadaptor_user

  Title    : dbadaptor_user
  Function : get/set for dbadaptor user 
  Example  : $io->dbadaptor_user($user);
  Returns  : the db user
  Args     : optionally, the new user

=cut

sub dbadaptor_user {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_user'} = $value;
  }
  return $self->{'_dbadaptor_user'};
}

=head2 dbadaptor_pass

  Title    : dbadaptor_pass
  Function : get/set for dbadaptor pass
  Example  : $io->dbadaptor_pass($pass);
  Returns  : the db pass
  Args     : optionally, the new pass

=cut

sub dbadaptor_pass {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_pass'} = $value;
  }
  return $self->{'_dbadaptor_pass'};
}

=head2 dbadaptor_port

  Title    : dbadaptor_port
  Function : get/set for dbadaptor port
  Example  : $io->dbadaptor_port($port);
  Returns  : the db port
  Args     : optionally, the new port

=cut

sub dbadaptor_port{
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_port'} = $value;
  }
  return $self->{'_dbadaptor_port'};
}

=head2 dbadaptor_module

  Title    : dbadaptor_module
  Function : get/set for dbadaptor module
  Example  : $io->dbadaptor_module($module);
  Returns  : the db module
  Args     : optionally, the new module

=cut

sub dbadaptor_module {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_module'} = $value;
  }
  return $self->{'_dbadaptor_module'};
}

=head2 dbadaptor_host

  Title    : dbadaptor_host
  Function : get/set for dbadaptor host 
  Example  : $io->dbadaptor_host($host);
  Returns  : the db host
  Args     : optionally, the new host

=cut

sub dbadaptor_host {
  my ($self,$value) = @_;
  if ($value){
    $self->{'_dbadaptor_host'} = $value;
  }
  return $self->{'_dbadaptor_host'};
}

=head2 stream_module

  Title    : stream_module
  Function : get/set for stream_module 
  Example  : $io->stream_module($module);
  Returns  : the name of the module e.g. Bio::DB::Fasta
  Args     : optionally, the new name

=cut

sub stream_module{
    my ($self,$value) = @_;
    if($value) {
        $self->{'_streammodule'} = $value;
    }
    return $self->{'_streammodule'};
}

=head2 adaptor_type

  Title    : adaptor_type
  Function : get/set for adaptor_type
  Example  : $io->adaptor_type($type);
  Returns  : the  type e.g. STREAM OR DB
  Args     : optionally, the new type 

=cut

sub adaptor_type {
    my ($self,$value) = @_;
    if($value) {
        $self->{'_dbtype'} = $value;
    }
    return $self->{'_dbtype'};
}

=head2 type

  Title    : type
  Function : get/set for type
  Example  : $io->type($type);
  Returns  : the data structure in which the iohandler handles 
             the input/output e.g. SCALAR OR ARRAY
  Args     : optionally, the newtype  

=cut

sub type {
    my ($self,$value) = @_;
    if($value) {
        $self->{'_iotype'} = $value;
    }
    return $self->{'_iotype'};
}

=head2 _load_dbadaptor

  Title    : _load_dbadaptor
  Function : loads the dbadaptor object 
  Example  : $io->_load_adaptor();
  Returns  : the dbadaptor object 
  Args     : 

=cut

sub _load_dbadaptor {
    my ($self,) = @_;
    return $self->{'_dbadaptor'} unless !$self->{'_dbadaptor'};

    my $dbname = $self->dbadaptor_dbname();
    my $driver = $self->dbadaptor_driver();
    my $host   = $self->dbadaptor_host();
    my $user   = $self->dbadaptor_user();
    my $pass   = $self->dbadaptor_pass();
    my $module = $self->dbadaptor_module();
    my $port   = $self->dbadaptor_port();

    $self->_load_module($module);

    $self->{'_dbadaptor'} = "${module}"->new(-dbname=>$dbname,-user=>$user,-host=>$host,-driver=>$driver,-pass=>$pass,-port=>$port);
    
    return $self->{'_dbadaptor'};
}

=head2 _load_obj

  Title    : _load_obj
  Function : loads an object
  Example  : $io->_load_obj("Bio::DB::Fasta","new");
  Returns  : the object
  Args     :

=cut

sub _load_obj {
    my ($self,$module,$method,@args) = @_;
    $module || $self->throw("Need an object to create object");
    $method = $method || 'new';

    $self->_load_module($module);

    my $obj = "${module}"->$method(@args);

    return $obj;
}
    
=head2 dbID

  Title   : dbID
  Usage   : $self->dbID($id)
  Function: get set the dbID for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut

sub dbID {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_dbID'} = $arg;
    }
    return $self->{'_dbID'};

}

=head2 adaptor

  Title   : adaptor
  Usage   : $self->adaptor($id)
  Function: get set the adaptor for this object, only used by Adaptor
  Returns : int
  Args    : int

=cut

sub adaptor {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_adaptor'} = $arg;
    }
    return $self->{'_adaptor'};

}

=head2 transformers

  Title   : transformers
  Usage   : $self->transformers($id)
  Function: get set the transformers for this object
  Returns : L<Bio::Pipeline::Transformer> 
  Args    : L<Bio::Pipelnie::Transformer> 

=cut

sub transformers {
    my ($self,$arg) = @_;

    if (defined($arg)) {
        $self->{'_transformers'} = $arg;
    }
    return $self->{'_transformers'};

}

=head2 analysis

  Title   : analysis
  Usage   : $self->analysis($id)
  Function: get set the analysis for this object
  Returns : L<Bio::Pipeline::Analysis> 
  Args    : L<Bio::Pipelnie::Analysis> 

=cut

sub analysis {
    my ($self,$analysis) = @_;
    if($analysis){
        $self->{'_analysis'} = $analysis;
    }
    return $self->{'_analysis'};
}

1;



    
          
