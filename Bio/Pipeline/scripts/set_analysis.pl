use DBI;
print "*********************************\n";
print "Bioperl-pipeline Analysis Tables Script\n";
print "*********************************\n";

print "New analysis information\n";

my $logic_name = &get_param("logic name");
my $db = &get_param("db"," ");
my $db_v;
my $db_f;
if ($db){
    $db_v = &get_param("db version"," ");
    $db_f = &get_param("db file"," ");
}
my $prog = &get_param("program");
my $prog_v,$prog_f;
if($prog){
  $prog_v = &get_param("program version"," ");
  $prog_f = &get_param("program file"," ");
}
my $parameters = &get_param("parameters"," ");
my $runnable = &get_param("runnable");
my $gff_source = &get_param("gff_source", " ");
my $gff_feature = &get_param("gff_feature", " ");

my $db = &get_param("biopipeline database name");
my $dbhost    = &get_param("db host","localhost");
my $driver = &get_param("db driver","mysql");
my $user = &get_param("db user","root");
my $pass = &get_param("pass"," ");
if($pass =~/^\s+$/){
	$pass ="";
}
my $dbstring = "database=$db;host=$dbhost;user=$user;pass=$pass";
my $dbh = dbconnect($dbstring);
my $insert = $dbh->prepare("INSERT INTO analysis (logic_name,
                                      db,
                                      db_version,
                                      db_file,
                                      program,
                                      program_version,
                                      program_file,
                                      parameters,
                                      runnable,
                                      gff_source,
                                      gff_feature)
                            values ('$logic_name','$db','$db_v','$db_f','$prog','$prog_v','$prog_f','$parameters',
                                    '$runnable','$gff_source','$gff_feature')");

$insert->execute;
my $id = $insert->{mysql_insertid};
print "Analysis $logic_name inserted into $db with internal id $id\n";

                                     

sub get_param {
   my ($name,$default) = @_;
   if (!defined $default){
    print ">>Kindly provide $name:(required)\n";
   }
   else {
    print ">>Kindly provide $name:[$default]\n";
   }

   my $input = <STDIN>;
   $input =~s/\n//;
   $input = $input || $default;
   if ($input =~/quit/i){
       print "ok quitter..\n";
       exit(1);
   }
   if (!defined $input){
       print "Need $name!\n";
       exit(1);
   }
   if ($input !~/^\s+$/){
     print "**$name is $input\n";
   }
   else {
     print "Leaving $name empty \n";
   }
   return $input;
}
sub dbconnect {
    my ($dbcs) = @_;

    my %keyvals= split('[=;]', $dbcs);
    my $user=$keyvals{'user'};
    my $paw=$keyvals{'pass'};
	if ($paw=~/^\s+$/){
		$paw ="";
	}
    my $dsn = "DBI:mysql:$dbcs";
    my $dbh=DBI->connect($dsn, $user, $paw) ||
    die "couldn't connect using dsn $dsn, user $user, password $paw:"
         . $DBI::errstr;
    $dbh;
}

