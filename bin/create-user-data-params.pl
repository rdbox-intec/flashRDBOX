#!/usr/bin/perl

use Getopt::Long qw(:config posix_default no_ignore_case gnu_compat);

my $infile = "user-data.params";
my $outfile = "user-data.params";

GetOptions(
  'infile|i=s' => \$infile,
  'outfile|o=s' => \$outfile,
  'help|h' => \$help
  );

my $help_message = "Usage: create-user-data-params.pl [options]
       [options]
        -i  [input list of parameter]   - default: user-data.params
        -o  [output list of parameter]  - default: user-data.params
        -h  print this message\n";

if ($help) {
  die $help_message;
}

my $os = &get_os();
  
my @not_required_params = ("HTTP_PROXY", "NO_PROXY", "EXTERNAL_CONNECT", "EXTERNAL_SSID", "EXTERNAL_PSK");
my %params = ();
my $salt = "roboticist";

$params{"IS_SIMPLE_FLG"} = "";
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

&load_params($infile, \%params);

print "\n";
STDOUT->flush();
sleep(1);

&interactive_process();

my $ecount = 0;

foreach my $key (sort keys %params) {
  if (grep { $_ eq $key } @not_required_params) {
    next;
  }
  if ($params{$key} eq "") {
    $ecount++;
    print "[ERROR] $key is empty.\n";
  }
}

if ($ecount > 0) {
  print "failed to create $outfile.\n";
  exit(-1);
}

print "The current parameters are as follows.\n\n";
&dump();
print "\n";

print "Do you want to continue?[y/N]\n";
STDOUT->flush();
my $ret = <STDIN>;
chomp($ret);
if ((length($ret) > 0) && ($ret =~ /^[yY]$/)) {
  &save_params($outfile, \%params);
} else {
  print "Canceled this processing.\n";
  exit(-1);
}

#-------------------------------------------------------------

sub get_os() {
  my $os = `uname -a | egrep -i -e '(GNU/Linux|Darwin)'`;
  if ($os =~ /^Linux/) {
    return "Debian";
  } elsif ($os =~ /^Darwin/) {
    return "Darwin";
  } else {
    return "";
  }
}

sub load_params() {
  my($infile, $params) = @_;

  print "$infile: loading...\n";
  
  if (open(PARAM, $infile)) {
    while ($line = <PARAM>) {
      if (($line =~ /^\s*\#/) || ($line =~ /^\s*$/)) {
        next;
      }

      if ($line =~ /^\s*(\S+)\s*=\s*(.+)\s*$/) {
        $$params{$1} = $2;
      }
    }

    close(PARAM);
    print "done.\n";
  } else {
    print "$infile: $! and so try to create the file.\n";
  }
}

sub save_params() {
  my($outfile, $params) = @_;

  print "$outfile: saving...\n";

  open(PARAM, "> $outfile") || die "$outfile: $!\n";
  
  for my $key (sort keys %$params) {
    print PARAM "$key=$$params{$key}\n";
  }

  close(PARAM);
  print "done.\n";
}

sub dump() {
  foreach my $key (sort keys %params) {
    print "$key => $params{$key}\n";
  }
}

sub interactive_process() {
  print "Do you want to use RDBOX's simple mode? [y/N]: ";
  STDOUT->flush();
  my $ret = <STDIN>;
  chomp($ret);
  if ((length($ret) > 0) && ($ret =~ /^[yY]$/)) {
    print "You chose the Simple version..\n";
    print "Please prepare 0 or 1 USB Wi-Fi dongles.\n\n";
    $params{'IS_SIMPLE_FLG'} = "true";
  } else {
    print "You chose the Full version..\n";
    print "Please prepare 4 USB Wi-Fi dongles.\n\n";
    $params{'IS_SIMPLE_FLG'} = "false";
  }
  sleep(1);

  #---
  if ($params{'IS_SIMPLE_FLG'} eq "true") {
    print "How do you connect to the external network? \n";
    print "0: Ethernet \n";
    print "1: Wi-Fi \n";
    print "What number do you select? [0-1]: ";
    $params{'EXTERNAL_CONNECT'} = &get_input("EXTERNAL_CONNECT[$params{'EXTERNAL_CONNECT'}]: ", $params{'EXTERNAL_CONNECT'}, 0);
    print "--> $params{'EXTERNAL_CONNECT'}\n\n";
    STDOUT->flush();
    sleep(1);
  }

  #---
  if (($params{'IS_SIMPLE_FLG'} eq "true") && ($params{'EXTERNAL_CONNECT'} eq "0")) {
    $params{'EXTERNAL_CONNECT'} = "";
    $params{'EXTERNAL_SSID'} = "";
    $params{'EXTERNAL_PSK'} = "";
  }

  #---
  if (($params{'IS_SIMPLE_FLG'} eq "true") && ($params{'EXTERNAL_CONNECT'} eq "1")) {
    print "[Change] SSID for /etc/rdbox/wpa_supplicant_yoursite.conf (connect to external network.)\n";
    $params{'EXTERNAL_SSID'} = &get_input("EXTERNAL_SSID[$params{'EXTERNAL_SSID'}]: ", $params{'EXTERNAL_SSID'}, 0);
    print "--> $params{'EXTERNAL_SSID'}\n\n";
    STDOUT->flush();
    sleep(1);
  }

  #---
  if (($params{'IS_SIMPLE_FLG'} eq "true") && ($params{'EXTERNAL_CONNECT'} eq "1")) {
    print "[Change] Password for SSID \'$params{'EXTERNAL_SSID'}\'.\n";
    my $tmp;
    ($tmp, $params{'EXTERNAL_PSK'}) = &get_wpa_psk("EXTERNAL_PASSWD[]: ", $params{'EXTERNAL_SSID'}, '', $params{'EXTERNAL_PSK'});
    print "PSK --> $params{'EXTERNAL_PSK'}\n\n";
    STDOUT->flush();
    sleep(1);
  }

  #---

  print "User name commonly used on machines on RDBOX network.\n";
  $params{'USER_NAME'} = &get_input("USER_NAME[$params{'USER_NAME'}]: ", $params{'USER_NAME'}, 0);
  print "--> $params{'USER_NAME'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Password for account \'$params{'USER_NAME'}\'.\n";
  if (length($params{'USER_PASSWD'}) == 0) {
    $dsp_passwd = "";
  } else {
    $dsp_passwd = "***";
  }
  $params{'USER_PASSWD'} = &get_passwd("Plain text of USER_PASSWD[$dsp_passwd]: ", $params{'USER_PASSWD'}, $salt);
  print "--> $params{'USER_PASSWD'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] SSH public key for account \'$params{'USER_NAME'}\'.\n";
  $params{'USER_SSH_AUTHORIZED_KEYS'} = &get_input("USER_SSH_AUTHORIZED_KEYS[$params{'USER_SSH_AUTHORIZED_KEYS'}]: ", $params{'USER_SSH_AUTHORIZED_KEYS'}, 0);
  print "--> $params{'USER_SSH_AUTHORIZED_KEYS'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Confirmation] OS locale.\n";
  $params{'LOCALE'} = &get_input("LOCALE[$params{'LOCALE'}]: ", $params{'LOCALE'}, 0);
  print "--> $params{'LOCALE'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Confirmation] OS timezone.\n";
  $params{'TIMEZONE'} = &get_input("TIMEZONE[$params{'TIMEZONE'}]: ", $params{'TIMEZONE'}, 0);
  print "--> $params{'TIMEZONE'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Confirmation] NTP server pool list (comma delimited).\n";
  $params{'NTP_POOLS'} = &get_input("NTP_POOLS[$params{'NTP_POOLS'}]: ", $params{'NTP_POOLS'}, 0);
  print "--> $params{'NTP_POOLS'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Confirmation] NTP server list (comma delimited).\n";
  $params{'NTP_SERVERS'} = &get_input("NTP_SERVERS[$params{'NTP_SERVERS'}]: ", $params{'NTP_SERVERS'}, 0);
  print "--> $params{'NTP_SERVERS'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] SSID for /etc/rdbox/wpa_supplicant_be.conf, /etc/rdbox/hostapd_be.conf.\n";
  $params{'BE_SSID'} = &get_wpa_ssid("BE_SSID[$params{'BE_SSID'}](auto-generation => '-'): ", $params{'BE_SSID'}, "", "", 12);
  print "--> $params{'BE_SSID'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Password for SSID \'$params{'BE_SSID'}\'.\n";
  if (length($params{'BE_PASSWD'}) == 0) {
    $dsp_passwd = "";
  } else {
    $dsp_passwd = "***";
  }
  ($params{'BE_PASSWD'}, $params{'BE_PSK'}) = &get_wpa_psk("BE_PASSWD[$dsp_passwd]: ", $params{'BE_SSID'}, $params{'BE_PASSWD'}, $params{'BE_PSK'});
  print "PSK --> $params{'BE_PSK'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] SSID for /etc/rdbox/wpa_supplicant_ap_bg.conf, /etc/rdbox/hostapd_ap_bg.conf.\n";
  $params{'AP_BG_SSID'} = &get_wpa_ssid("AP_BG_SSID[$params{'AP_BG_SSID'}](auto-generation => '-'): ", $params{'AP_BG_SSID'}, "rdbox-", "-g", 8);
  print "--> $params{'AP_BG_SSID'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Password for SSID \'$params{'AP_BG_SSID'}\'.\n";
  if (length($params{'AP_BG_PASSWD'}) == 0) {
    $dsp_passwd = "";
  } else {
    $dsp_passwd = "***";
  }
  ($params{'AP_BG_PASSWD'}, $params{'AP_BG_PSK'}) = &get_wpa_psk("AP_BG_PASSWD[$dsp_passwd]: ", $params{'AP_BG_SSID'}, $params{'AP_BG_PASSWD'}, $params{'AP_BG_PSK'});
  print "PSK --> $params{'AP_BG_PSK'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] SSID for /etc/rdbox/hostapd_ap_an.conf.\n";
  $params{'AP_AN_SSID'} = &get_wpa_ssid("AP_AN_SSID[$params{'AP_AN_SSID'}](auto-generation => '-'): ", $params{'AP_AN_SSID'}, "rdbox-", "-a", 8);
  print "$params{'AP_AN_SSID'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Password for SSID \'$params{'AP_AN_SSID'}\'.\n";
  if (length($params{'AP_AN_PASSWD'}) == 0) {
    $dsp_passwd = "";
  } else {
    $dsp_passwd = "***";
  }
  ($params{'AP_AN_PASSWD'}, $params{'AP_AN_PSK'}) = &get_wpa_psk("AP_AN_PASSWD[$dsp_passwd]: ", $params{'AP_AN_SSID'}, $params{'AP_AN_PASSWD'}, $params{'AP_AN_PSK'});
  print "PSK --> $params{'AP_AN_PSK'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] VPN server address. ** ONLY \"IP ADDRESS\" WITHOUT PORT **\n";
  $params{'VPN_SERVER_ADDRESS'} = &get_input("VPN_SERVER_ADDRESS[$params{'VPN_SERVER_ADDRESS'}]: ", $params{'VPN_SERVER_ADDRESS'}, 0);
  print "--> $params{'VPN_SERVER_ADDRESS'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "VPN hub name.\n";
  $params{'VPN_HUB_NAME'} = &get_input("VPN_HUB_NAME[$params{'VPN_HUB_NAME'}]: ", $params{'VPN_HUB_NAME'}, 0);
  print "--> $params{'VPN_HUB_NAME'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Username for connecting to the VPN server.\n";
  $params{'VPN_USER_NAME'} = &get_input("VPN_USER_NAME[$params{'VPN_USER_NAME'}]: ", $params{'VPN_USER_NAME'}, 0);
  print "--> $params{'VPN_USER_NAME'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "[Change] Password for connecting to the VPN server.\n";
  $params{'VPN_USER_PASS'} = &get_input("VPN_USER_PASS[$params{'VPN_USER_PASS'}]: ", $params{'VPN_USER_PASS'}, 0);
  print "--> $params{'VPN_USER_PASS'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "Configure the transparent proxy service. (if necessary)\n";
  print "Please do not change if you do not use proxy service.\n";
  print "For http_proxy, specify the address of the proxy server of your organization starting with http.\n";
  $params{'HTTP_PROXY'} = &get_input("HTTP_PROXY[$params{'HTTP_PROXY'}]: ", $params{'HTTP_PROXY'}, 1);
  print "--> $params{'HTTP_PROXY'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "Please do not change if you do not use proxy service.\n";
  print "For no_proxy, you need to access directly for internal. Also you can use IP Address, CIDR in no_proxy. (comma delimited).\n";
  $params{'NO_PROXY'} = &get_input("NO_PROXY[$params{'NO_PROXY'}]: ", $params{'NO_PROXY'}, 1);
  print "--> $params{'NO_PROXY'}\n\n";
  STDOUT->flush();
  sleep(1);

  #---

  print "Arguments for kubeadm join <ARGS>.\n";
  $params{'KUBEADM_JOIN_ARGS'} = &get_input("KUBEADM_JOIN_ARGS[$params{'KUBEADM_JOIN_ARGS'}]: ", $params{'KUBEADM_JOIN_ARGS'}, 0);
  print "--> $params{'KUBEADM_JOIN_ARGS'}\n\n";
  STDOUT->flush();
  sleep(1);
}

sub get_input() {
  my($prompt, $init_data, $empty_ok) = @_;
  my $data = "";

  while (true) {
    print "$prompt";
    STDOUT->flush();
    my $input = <STDIN>;
    chomp($input);
    if (length($input) > 0) {
      $data = $input;
      last;
    } else {
      if ($init_data =~ /^$/) {
        if ($empty_ok == 1) {
          last;
        } else {
          next;
        }
      } else {
        $data = $init_data;
        last;
      }
    }
  }
  return $data;
}

sub get_passwd() {
  my($prompt, $init_data, $salt) = @_;
  my $data = "";

  while (true) {
    print "$prompt";
    STDOUT->flush();
    my $input = <STDIN>;
    chomp($input);
    if (length($input) > 0) {
        if ($os =~ /Debian/) {
          $data = `echo -n \"$input\" | mkpasswd --method=SHA-512 -s -S \"$salt\"`;
          chomp($data);
          last;
        } elsif ($os =~ /Darwin/) {
          $data = $input;
          last;
        } else {
          next;
        }
    } else {
      if ($init_data =~ /^$/) {
        next;
      } else {
        $data = $init_data;
        last;
      }
    }
  }
  return $data;
}

sub get_wpa_ssid() {
  my($prompt, $init_data, $prefix, $suffix, $length) = @_;
  my $data = "";

  while (true) {
    print "$prompt";
    STDOUT->flush();
    my $input = <STDIN>;
    chomp($input);
    if (length($input) > 0) {
      if ($input =~ /^\-$/) {
        my $line = `uuidgen | sed -e 's/\-//g'`;
        chomp($line);
        $data = $prefix . substr($line, 0, $length) . $suffix;
        last;
      } else {
        $data = $prefix . substr($input, 0, $length) . $suffix;
        last;
      }
    } else {
      if ($init_data =~ /^$/) {
        next;
      } else {
        $data = $init_data;
        last;
      }
    }
  }
  return $data;
}

sub get_wpa_psk() {
  my($prompt, $ssid, $init_passwd, $init_psk) = @_;
  my $passwd = "";
  my $psk = "";

  while (true) {
    print "$prompt";
    STDOUT->flush();
    $passwd = <STDIN>;
    chomp($passwd);
    if (length($passwd) > 0) {
      if (length($passwd) < 8 || length($passwd) > 63) {
        print "The passphrase must be 8 to 63 characters in length.\n";
        next;
      } else {
        if ($os =~ /Debian/) {
          $psk = `wpa_passphrase \"$ssid\" \"$passwd\" |grep 'psk=' | grep -v '#psk=' | sed -e 's/.*psk=//g'`;
          chomp($psk);
          last;
        } elsif ($os =~ /Darwin/) {
          $psk = $passwd;
          last;
        } else {
          next;
        }
      }
    } else {
      if ($init_passwd =~ /^$/) {
        next;
      } else {
        $passwd = $init_passwd;
        $psk = $init_psk;
        last;
      }
    }
  }
  ($passwd, $psk);
}
