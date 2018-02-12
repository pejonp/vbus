##############################################
# $Id: 19_VBUSIF.pm 20170226 2017-02-26 10:10:10Z awk+pejonp $
#
# VBUS LAN Adapter Device
# 19_VBUSIF.pm
#
# (c) 2014 Arno Willig <akw@bytefeed.de>
# (c) 2015 Frank Wurdinger <frank@wurdinger.de>
# (c) 2015 Adrian Freihofer <adrian.freihofer gmail com>
# (c) 2016 Tobias Faust <tobias.faust gmx net>
# (c) 2016 Jörg (pejonp)
##############################################  


package main;

use strict;
use warnings;
use POSIX;
use Data::Dumper;
use Device::SerialPort;

sub VBUSIF_Read($@);
sub VBUSIF_Write($$$);
sub VBUSIF_Ready($);
sub VBUSIF_getDevList($$);


our $VBUS_pwd;

sub VBUSIF_Initialize($)
{
	my ($hash) = @_;
	require "$attr{global}{modpath}/FHEM/DevIo.pm";

# Provider
	$hash->{ReadFn}     = "VBUSIF_Read";
	$hash->{WriteFn}    = "VBUSIF_Write";
	$hash->{ReadyFn}    = "VBUSIF_Ready";
	$hash->{UndefFn}    = "VBUSIF_Undef";
	$hash->{ShutdownFn} = "VBUSIF_Undef";
  $hash->{SetFn}      = "VBUSIF_Set";
# Normal devices
	$hash->{DefFn}      = "VBUSIF_Define";
	$hash->{AttrList}   = "dummy:1,0"
                        ."$readingFnAttributes ";
  $hash->{AutoCreate}	= { "VBUSDEF.*" => { ATTR => "event-min-interval:.*:120 event-on-change-reading:.* ",FILTER => "%NAME"} };
  
}

######################################
sub VBUSIF_Define($$)
{
	my ($hash, $def) = @_;
	my @a = split("[ \t]+", $def);

	if(@a != 3) {
		my $msg = "wrong syntax: define <name> VBUSIF [<hostname:7053> or <dev>]";
    Log3 $hash, 2, $msg;
    return $msg;
	}

#  if(@a != 3) {
#		return "wrong syntax: define <name> VBUSIF [<hostname:7053> or <dev>]";
#	}


	my $name = $a[0];
	my $dev = $a[2];
	$hash->{Clients} = ":VBUSDEV:";
	my %matchList = ( "1:VBUSDEV" => ".*" );
	$hash->{MatchList} = \%matchList;

  Log3 $hash, 4,"$name:  VBUSIF_Define: $hash->{MatchList} ";

	DevIo_CloseDev($hash);
	$hash->{DeviceName} = $dev;
	my @dev_name = split('@', $dev);
	if ( -c ${dev_name}[0]) {
		$hash->{DeviceType} = "Serial";
	} else {
		$hash->{DeviceType} = "Net";
	}

	my $ret = DevIo_OpenDev($hash, 0, "VBUSIF_DoInit");
	return $ret;
}
###############################
sub VBUSIF_DoInit($)
{
	my $hash = shift;
	if ($hash->{DeviceType} eq "Net" ) {
		my $name = $hash->{NAME};
    my $pwd = VBUSIF_readPassword($hash);
    
    unless (defined $pwd) {
      Log3 $hash, 2, "Error: No password set. Please define it (once) with 'set $name password YourPassword'";
      return undef;
   }

		delete $hash->{HANDLE}; # else reregister fails / RELEASE is deadly
		my $conn = $hash->{TCPDev};
		$conn->autoflush(1);
		$conn->getline();
		$conn->write("PASS ".$pwd."\n");
		$conn->getline();
		$conn->write("DATA\n");
		$conn->getline();
    Log3 $hash, 4,"$name:  VBUSIF_Define: VBUSIF_DoInit ";
	}
	return undef;
}

sub VBUSIF_Undef($@)
{
	my ($hash, $arg) = @_;
	if ($hash->{DeviceType} eq "Net" ) {
		VBUSIF_Write($hash, "QUIT\n", "");  # RELEASE
	}
	DevIo_CloseDev($hash);
	return undef;
}

sub VBUSIF_Write($$$)
{
	my ($hash,$fn,$msg) = @_;
	DevIo_SimpleWrite($hash, $msg, 1);
}

sub VBUSIF_Read($@)
{
	my ($hash, $local, $regexp) = @_;
	my $buf = ($local ? $local : DevIo_SimpleRead($hash));
	return "" if(!defined($buf));
	my $name = $hash->{NAME};
	$buf = unpack('H*', $buf);
	my $data = ($hash->{PARTIAL} ? $hash->{PARTIAL} : "");
	$data .= $buf;
  
	my $msg;
  my $msg2;
	my $idx;
  my $muster = "aa";
	$idx = index($data,$muster);
  Log3 $hash, 4,"$name:  VBUSIF_Read0: Data = $data";
  
	if ($idx>=0) {
    $msg2 = $data;
		$data = substr($data,$idx); # Cut off beginning
  	$idx = index($data,$muster,2); # Find next message

		if ($idx>0) {
    
    	$idx +=1 if (substr($data,$idx,3) eq "aaa"); # Message endet mit a
    
			$msg = substr($data,0,$idx);
			$data = substr($data,$idx);
			my $protoVersion = substr($msg,10,2);
    	Log3 $hash, 4,"$name:  VBUSIF_Read1: protoVersion : $protoVersion";
      
  	  if ($protoVersion == "10" && length($msg)>=20) {
			  	my $frameCount = hex(substr($msg,16,2));
				  my $headerCRC  = hex(substr($msg,18,2));
  				my $crc = 0;
	  			for (my $j = 1; $j<=8;$j++) {
		  			$crc += hex(substr($msg,$j*2,2));
			  	}
				  $crc = ($crc ^ 0xff) & 0x7f;
				  if ($headerCRC != $crc) {
	             Log3 $hash, 3, "$name:  VBUSIF_Read2: Wrong checksum: $crc != $headerCRC";
				    } else {
					     my $len = 20+12*$frameCount;
               Log3 $hash, 4,"$name:  VBUSIF_Read2a Len: ".$len." Counter: ".$frameCount;
      				 
              # if ($len != length($msg)){
               # Fehler bei aa1000277310000103414a7f1300071c00001401006a62023000016aaa000021732000050000000000000046a
               #                                                                   ^ hier wird falsch getrennt
              #    $msg = substr($msg2,0,$len);
              #    Log3 $hash, 4,"$name: VBUSIF_Read2b MSG: ".$msg;
              # }
               
               if ($len != length($msg)) {
                 Log3 $hash, 4,"$name:  VBUSIF_Read3: Wrong message length: $len != ".length($msg);
					      } else {
                 Log3 $hash, 4,"$name:  VBUSIF_Read4: OK message length: $len : ".length($msg);
  				        my $payload = VBUSIF_DecodePayload($hash,$msg);
	  			        if (defined $payload) {
							        $msg = substr($msg,0,20).$payload;
                      Log3 $hash, 4,"$name:  VBUSIF_Read6 MSG: ".$msg." Payload: ".$payload;
							        $hash->{"${name}_MSGCNT"}++;
							        $hash->{"${name}_TIME"} = TimeNow();
						        	$hash->{RAWMSG} = $msg;
							        my %addvals = (RAWMSG => $msg);
							        Dispatch($hash, $msg, \%addvals) if($init_done);
	  					      }
					         }
        			}
   		}
      
			if ($protoVersion == "20") {
				my $command    = substr($msg,14,2).substr($msg,12,2);
				my $dataPntId  = substr($msg,16,4);
				my $dataPntVal = substr($msg,20,8);
				my $septet     = substr($msg,28,2);
				my $checksum   = substr($msg,30,2);
        
        Log3 $hash, 4,"$name:  VBUSIF_Read7: Version : $protoVersion CMD: $command ID: $dataPntId Val: $dataPntVal tet: $septet CRC: $checksum ";
#				TODO use septet
#				TODO validate checksum
#				TODO Understand protocol

			}
      	Log3 $hash, 4,"$name:  VBUSIF_Read8: raus ";
		}
	} else {
      Log3 $hash->{NAME}, 3,"$name:  VBUSIF_Read_Ende: $data ";
      return "";
  }


	$hash->{PARTIAL} = $data;
#	return $msg if(defined($local));
	return undef;
}

sub VBUSIF_Ready($)
{
	my ($hash) = @_;
	return DevIo_OpenDev($hash, 1, "VBUSIF_DoInit") if($hash->{STATE} eq "disconnected");
	return 0;
}


sub VBUSIF_DecodePayload($@)
{
	my ($hash, $msg) = @_;
	my $name = $hash->{NAME};

	my $frameCount = hex(substr($msg,16,2));
	my $payload = "";
	for (my $i = 0; $i < $frameCount; $i++) {
		my $septet   = hex(substr($msg,28+$i*12,2));
		my $frameCRC = hex(substr($msg,30+$i*12,2));

		my $crc = (0x7f - $septet) & 0x7f;
		for (my $j = 0; $j<4;$j++) {
			my $ch = hex(substr($msg,20+$i*12+$j*2,2));
			$ch |= 0x80 if ($septet & (1 << $j));
			$crc = ($crc - $ch) & 0x7f;
			$payload .= chr($ch);
		}

		if ($crc != $frameCRC) {
		   Log3 $hash, 4,"$name:  VBUSIF_DecodePayload0: Wrong checksum: $crc != $frameCRC";
			return undef;
		}
	}
	return unpack('H*', $payload);
}


sub VBUSIF_Set($$@) 
{
   my ($hash, $name, $cmd, @val) = @_;
   my $resultStr = "";
   my $list = "password";
            
   if ( lc $cmd eq 'password') {
      if (int @val == 1) 
      {
         return VBUSIF_storePassword ( $hash, $val[0] );
      }
 }
    return "Unknown argument $cmd or wrong parameter(s), choose one of $list"; 
}     # end VBUSIF_Set

#####################################
# checks and stores VBUS password used for telnet connection
sub VBUSIF_storePassword($$)
{
    my ($hash, $password) = @_;
     
    my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
    my $key = getUniqueId().$index;
    
    my $enc_pwd = "";
    
    if(eval "use Digest::MD5;1")
    {
        $key = Digest::MD5::md5_hex(unpack "H*", $key);
        $key .= Digest::MD5::md5_hex($key);
    }
    
    for my $char (split //, $password)
    {
        my $encode=chop($key);
        $enc_pwd.=sprintf("%.2x",ord($char)^ord($encode));
        $key=$encode.$key;
    }
    
    my $err = setKeyValue($index, $enc_pwd);
    return "error while saving the password - $err" if(defined($err));
    
    return "password successfully saved";
} # end VBUSIF_storePassword
#####################################
#####################################
# reads the VBUS password
sub VBUSIF_readPassword($)
{
   my ($hash) = @_;
   my $name = $hash->{NAME};

   my $index = $hash->{TYPE}."_".$hash->{NAME}."_passwd";
   my $key = getUniqueId().$index;

   my ($password, $err);

   Log3 $hash, 5, "Read VBUS password from file";
   ($err, $password) = getKeyValue($index);

   if ( defined($err) ) {
      Log3 $hash, 4, "unable to read VBUS password from file: $err";
      return undef;
   }  
    
   if ( defined($password) ) {
      if ( eval "use Digest::MD5;1" ) {
         $key = Digest::MD5::md5_hex(unpack "H*", $key);
         $key .= Digest::MD5::md5_hex($key);
      }

      my $dec_pwd = '';
     
      for my $char (map { pack('C', hex($_)) } ($password =~ /(..)/g)) {
         my $decode=chop($key);
         $dec_pwd.=chr(ord($char)^ord($decode));
         $key=$decode.$key;
      }
     
      return $dec_pwd;
   }
   else {
      Log3 $hash, 4, "No password in file";
      return undef;
   }
} # end VBUS_readPassword


1;

=pod
=item device
=item summary    connects to the RESOL VBUS LAN or Serial Port adapter 
=item summary_DE verbindet sich mit einem RESOL VBUS LAN oder Seriell Adapter
=begin html

<a name="VBUSIF"></a>
<h3>VBUSIF</h3>
<ul>
  This module connects to the RESOL VBUS LAN or Serial Port adapter.
  It serves as the "physical" counterpart to the <a href="#VBUSDEV">VBUSDevice</a>
  devices.
  <br>
  It uses the perl modul Digest::MD5. 
  <br/>
  <a name="VBUSIF_Define"></a>
  <b>Define</b>
  <ul>
    <code>define &lt;name&gt; VBUSIF &lt;device&gt;</code>
  <br/>
  <br/>
  &lt;device&gt; is a &lt;host&gt;:&lt;port&gt; combination, where
  &lt;host&gt; is the address of the RESOL LAN Adapter and &lt;port&gt; 7053.
  <br/>
  Please note: the password of RESOL Device must be define with 'set &lt;name&gt; password YourPassword'
  <br/>
  Examples:
  <ul>
    <code>define vbus VBUSIF 192.168.1.69:7053</code>
    </ul>
    <ul>
    <code>define vbus VBUSIF  /dev/ttyS0</code>
  </ul>
  </ul>
  <br/>
</ul>

=end html
=cut
