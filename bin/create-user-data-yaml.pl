#!/usr/bin/perl

use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my $infile = "user-data.yml.in";
my $outfile = "user-data.yml";
my $paramfile = "user-data.params";

GetOptions(
  'infile|i=s' => \$infile,
  'outfile|o=s' => \$outfile,
  'paramfile|p=s' => \$paramfile,
  'help|h' => \$help
  );

my $help_message = "Usage: create-user-data-yaml.pl [options]
       [options]
        -i  [template of user-data.yml] - default: user-data.yml.in
        -o  [output user-data.yml]      - default: user-data.yml
        -p  [list of parameter]         - default: user-data.params
        -h  print this message\n";

if ($help) {
  die $help_message;
}

(-f $infile) || die "$infile: $!\n---\n$help_message";
(-f $paramfile) || die "$paramfile: $!\n---\n$help_message";
  
my @not_required_params = ("HTTP_PROXY", "NO_PROXY", "EXTERNAL_CONNECT", "EXTERNAL_SSID", "EXTERNAL_PSK");
my %params = ();

$params["IS_SIMPLE_FLG"] = "";
$params{"EXTERNAL_CONNECT"} = "";
$params{"EXTERNAL_SSID"} = "";
$params{"EXTERNAL_PSK"}= "";
$params{"USER_NAME"} = "";
$params{"USER_PASSWD"} = "";
$params{"USER_SSH_AUTHORIZED_KEYS"} = "";
$params{"LOCALE"} = "";
$params{"TIMEZONE"} = "";
$params{"NTP_POOLS"} = "";
$params{"NTP_SERVERS"} = "";
$params{"BE_SSID"} = "";
$params{"BE_PASSWD"} = "";
$params{"BE_PSK"} = "";
$params{"AP_BG_SSID"} = "";
$params{"AP_BG_PASSWD"} = "";
$params{"AP_BG_PSK"} = "";
$params{"AP_AN_SSID"} = "";
$params{"AP_AN_PASSWD"} = "";
$params{"AP_AN_PSK"} = "";
$params{"VPN_SERVER_ADDRESS"} = "";
$params{"VPN_HUB_NAME"} = "";
$params{"VPN_USER_NAME"} = "";
$params{"VPN_USER_PASS"} = "";
$params{"HTTP_PROXY"} = "";
$params{"NO_PROXY"} = "";
$params{"KUBEADM_JOIN_ARGS"} = "";

open(PARAM, $paramfile) || die "$paramfile: $!\n";

while ($line = <PARAM>) {
  if (($line =~ /^\s*\#/) || ($line =~ /^\s*$/)) {
    next;
  }

  if ($line =~ /^\s*(\S+)\s*=\s*(.+)\s*$/) {
    my $key = $1;
    my $val = $2;

    if (($key =~ /^NTP_POOLS$/) || ($key =~ /^NTP_SERVERS$/)) {
      $params{$key} = &get_ntp_list($val);
    } else {
      $params{$key} = $val;
    }
  }
}

close(PARAM);

my $ecount = 0;

foreach my $key (sort keys %params) {
  if (grep { $_ eq $key } @not_required_params) {
    next;
  }
  if ($params{$key} eq "") {
    $ecount++;
    print STDERR "[ERROR] $key is empty.\n";
  }
}

$ecount == 0 || die "failed to create $outfile.\n";

print "creating $infile => $outfile by $paramfile...\n";

$content = &load_file($infile);

foreach my $key (sort { length $b <=> length $a || $a cmp $b } keys %params) {
  $content =~ s/$key/$params{$key}/g;
}

&save_file($outfile, $content);

print "done.\n";

#-------------------------------------------------------------

sub load_file() {
  my($filename) = @_;

  open(IN, "< $filename") || die "$filename: $!\n";
  binmode IN;
  local $/ = undef;
  my $data = <IN>;
  close(IN);

  return $data;
}

sub save_file() {
  my($filename, $data) = @_;

  open(OUT, "> $filename") || die "$filename: $!\n";
  binmode OUT;
  local $/ = undef;
  print OUT $data;
  close(OUT);
}

sub get_ntp_list() {
  my($line) = @_;
  my @list = split(/[\,\s]+/, $line);
  my $joinedList = "";
  my $indent = "        ";
  my $prefix = "- ";

  if ($#list >= 0) {
    $joinedList = $prefix;
    $joinedList .= join("\n$indent$prefix", @list);
  }

  return $joinedList;
}

sub dump() {
  foreach my $key (sort keys %params) {
    print "$key => $params{$key}\n";
  }
}
