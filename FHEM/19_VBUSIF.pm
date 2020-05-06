##############################################
# $Id: 19_VBUSIF.pm 20200506 2020-05-06 10:10:10Z pejonp $
#
# VBUS LAN Adapter Device
# 19_VBUSIF.pm
#
# (c) 2014 Arno Willig <akw@bytefeed.de>
# (c) 2015 Frank Wurdinger <frank@wurdinger.de>
# (c) 2015 Adrian Freihofer <adrian.freihofer gmail com>
# (c) 2016 Tobias Faust <tobias.faust gmx net>
# (c) 2016 Jörg (pejonp)
# (c) 20.04.2020 Anpassungen Perl (pejonp)
# (c) 06.05.2020 Fehlerbereinigung nach PBP (pejonp)
# 
##############################################

package FHEM::VBUSIF;
use strict;
use warnings;
no if $] >= 5.017011, warnings => 'experimental::smartmatch';
#no warnings 'portable';    # Support for 64-bit ints required
use Data::Dumper;
use Device::SerialPort;
use GPUtils qw(GP_Import GP_Export);
use Time::HiRes qw(gettimeofday usleep);
use Scalar::Util qw(looks_like_number);
use feature qw/say switch/;
use Digest::MD5;
use FHEM::Meta;


## Import der FHEM Funktionen
#-- Run before package compilation
BEGIN {

    # Import from main context
    GP_Import(
        qw(
          readingsBulkUpdate
          readingsBeginUpdate
          readingsEndUpdate
          defs
          modules
          Log3
          attr
          readingFnAttributes
          AttrVal
          ReadingsVal
          Value
          FmtDateTime
          strftime
          GetTimeSpec
          InternalTimer
          AssignIoPort
          DevIo_CloseDev
          DevIo_OpenDev
          DevIo_SimpleWrite
          DevIo_SimpleRead
          RemoveInternalTimer
          getUniqueId
          getKeyValue
          setKeyValue
          TimeNow
          Dispatch
           )
    );
}

#-- Export to main context with different name
GP_Export(
    qw(
      Initialize
      )
);

sub Initialize() {
    my $hash = shift;
    require "$attr{global}{modpath}/FHEM/DevIo.pm";
  
    # Provider
    $hash->{ReadFn}     = \&Read;
    $hash->{WriteFn}    = \&Write;
    $hash->{ReadyFn}    = \&Ready;
    $hash->{UndefFn}    = \&Undef;
    #$hash->{ShutdownFn} = \&Undef;
    $hash->{SetFn}      = \&Set;
    $hash->{DefFn}      = \&Define;
    $hash->{AttrList}   = "dummy:1,0" .$readingFnAttributes;
    $hash->{AutoCreate} = {
        "VBUSDEF.*" => {
            ATTR   => "event-min-interval:.*:120 event-on-change-reading:.* ",
            FILTER => "%NAME"
        }
    };
    return;
}

######################################
sub Define() {
    my $hash = shift;
    my $def = shift;
    my @a = split( "[ \t]+", $def );

    if ( @a != 3 ) {
        my $msg =
          "wrong syntax: define <name> VBUSIF [<hostname:7053> or <dev>]";
        Log3 $hash, 2, $msg;
        return $msg;
    }

    #  if(@a != 3) {
    #		return "wrong syntax: define <name> VBUSIF [<hostname:7053> or <dev>]";
    #	}

    my $name = $a[0];
    my $dev  = $a[2];
    $hash->{Clients} = ":VBUSDEV:";
    my %matchList = ( "1:VBUSDEV" => ".*" );
    $hash->{MatchList} = \%matchList;

    Log3 $hash, 4, "$name:  Define: $hash->{MatchList} ";

    DevIo_CloseDev($hash);
    $hash->{DeviceName} = $dev;
    my @dev_name = split( '@', $dev );
    if ( -c ${dev_name}[0] ) {
        $hash->{DeviceType} = "Serial";
    }
    else {
        $hash->{DeviceType} = "Net";
    }
    my $ret = DevIo_OpenDev( $hash, 0, "FHEM::VBUSIF::Init" );
    return $ret;
}
###############################
sub Init() {
    my $hash = shift;
    if ( $hash->{DeviceType} eq "Net" ) {
        my $name = $hash->{NAME};
        my $pwd  = readPassword($hash);

        unless ( defined $pwd ) {
            Log3 $hash, 2,
"Error: No password set. Please define it (once) with 'set $name password YourPassword'";
            return;
        }

        delete $hash->{HANDLE};    # else reregister fails / RELEASE is deadly
        my $conn = $hash->{TCPDev};
        $conn->autoflush(1);
        $conn->getline();
        $conn->write( "PASS " . $pwd . "\n" );
        $conn->getline();
        $conn->write("DATA\n");
        $conn->getline();
        Log3 $hash, 4, "$name:  Define: InitIO ";
    }
    return;
}

sub Undef() {
    my $hash = shift;
    my $arg = shift;
    if ( $hash->{DeviceType} eq "Net" ) {
        Write( $hash, "QUIT\n", "" );    # RELEASE
    }
    DevIo_CloseDev($hash);
    return;
}

sub Write() {
    my $hash = shift;
    my $fn = shift;
    my $msg = shift;
    DevIo_SimpleWrite( $hash, $msg, 1 );
    return;
}

sub Read() {
    my $hash = shift;
    my $local = shift;
    my $regexp = shift;
    my $buf = ( $local ? $local : DevIo_SimpleRead($hash) );
    return "" if ( !defined($buf) );
    my $name = $hash->{NAME};
    $buf = unpack( 'H*', $buf );
    my $data = ( $hash->{PARTIAL} ? $hash->{PARTIAL} : "" );
    $data .= $buf;

    my $msg;
    my $msg2;
    my $idx;
    my $muster = "aa";
    $idx = index( $data, $muster );
    Log3 $hash, 4, "$name:  Read0: Data = $data";

    if ( $idx >= 0 ) {
        $msg2 = $data;
        $data = substr( $data, $idx );         # Cut off beginning
        $idx  = index( $data, $muster, 2 );    # Find next message

        if ( $idx > 0 ) {

            $idx += 1
              if ( substr( $data, $idx, 3 ) eq "aaa" );    # Message endet mit a

            $msg  = substr( $data, 0, $idx );
            $data = "";                                    #substr($data,$idx);
            my $protoVersion = substr( $msg, 10, 2 );
            Log3 $hash, 4, "$name:  Read1: protoVersion : $protoVersion";

            if ( $protoVersion == "10" && length($msg) >= 20 ) {
                my $frameCount = hex( substr( $msg, 16, 2 ) );
                my $headerCRC  = hex( substr( $msg, 18, 2 ) );
                my $crc        = 0;
                for ( my $j = 1 ; $j <= 8 ; $j++ ) {
                    $crc += hex( substr( $msg, $j * 2, 2 ) );
                }
                $crc = ( $crc ^ 0xff ) & 0x7f;
                if ( $headerCRC != $crc ) {
                    Log3 $hash, 3,
"$name:  Read2: Wrong checksum: $crc != $headerCRC";
                }
                else {
                    my $len = 20 + 12 * $frameCount;
                    Log3 $hash, 4,
                        "$name:  Read2a Len: "
                      . $len
                      . " Counter: "
                      . $frameCount;

# if ($len != length($msg)){
# Fehler bei aa1000277310000103414a7f1300071c00001401006a62023000016aaa000021732000050000000000000046a
#                                                                   ^ hier wird falsch getrennt
#    $msg = substr($msg2,0,$len);
#    Log3 $hash, 4,"$name: Read2b MSG: ".$msg;
# }

                    if ( $len != length($msg) ) {
                        Log3 $hash, 4,
                          "$name:  Read3: Wrong message length: $len != "
                          . length($msg);
                    }
                    else {
                        Log3 $hash, 4,
                          "$name:  Read4: OK message length: $len : "
                          . length($msg);
                        my $payload = DecodePayload( $hash, $msg );
                        if ( defined $payload ) {
                            $msg = substr( $msg, 0, 20 ) . $payload;
                            Log3 $hash, 4,
                                "$name:  Read6 MSG: "
                              . $msg
                              . " Payload: "
                              . $payload;
                            $hash->{"${name}_MSGCNT"}++;
                            $hash->{"${name}_TIME"} = TimeNow();
                            $hash->{RAWMSG}         = $msg;
                            my %addvals = ( RAWMSG => $msg );
                       #     Dispatch( $hash, $msg, \%addvals ) if ($init_done);
                            Dispatch( $hash, $msg, \%addvals );
                        }
                    }
                }
            }

            if ( $protoVersion == "20" ) {
                my $command    = substr( $msg, 14, 2 ) . substr( $msg, 12, 2 );
                my $dataPntId  = substr( $msg, 16, 4 );
                my $dataPntVal = substr( $msg, 20, 8 );
                my $septet     = substr( $msg, 28, 2 );
                my $checksum   = substr( $msg, 30, 2 );

                Log3 $hash, 4,
"$name:  Read7: Version : $protoVersion CMD: $command ID: $dataPntId Val: $dataPntVal tet: $septet CRC: $checksum ";

                #				TODO use septet
                #				TODO validate checksum
                #				TODO Understand protocol

            }
            Log3 $hash, 4, "$name:  Read8: raus ";
        }
    }
    else {
        Log3 $hash->{NAME}, 4, "$name:  Read_Ende: $data ";
     #   return;
    }

    $hash->{PARTIAL} = $data;

    #	return $msg if(defined($local));
    return;
}

sub Ready() {
    my $hash = shift;
    return DevIo_OpenDev( $hash, 1, "FHEM::VBUSIF::Init" )
      if ( $hash->{STATE} eq "disconnected" );
    return;
}

sub DecodePayload() {
    my $hash = shift;
    my $msg = shift;
    
    my $name = $hash->{NAME};

    my $frameCount = hex( substr( $msg, 16, 2 ) );
    my $payload    = "";
    for ( my $i = 0 ; $i < $frameCount ; $i++ ) {
        my $septet   = hex( substr( $msg, 28 + $i * 12, 2 ) );
        my $frameCRC = hex( substr( $msg, 30 + $i * 12, 2 ) );

        my $crc = ( 0x7f - $septet ) & 0x7f;
        for ( my $j = 0 ; $j < 4 ; $j++ ) {
            my $ch = hex( substr( $msg, 20 + $i * 12 + $j * 2, 2 ) );
            $ch |= 0x80 if ( $septet & ( 1 << $j ) );
            $crc = ( $crc - $ch ) & 0x7f;
            $payload .= chr($ch);
        }

        if ( $crc != $frameCRC ) {
            Log3 $hash, 4,
"$name:  DecodePayload0: Wrong checksum: $crc != $frameCRC";
            return;
        }
    }
    return unpack( 'H*', $payload );
}

sub Set() {
    my $hash = shift;
    my $name = shift;
    my $cmd = shift;
    my @val = shift;
    my $resultStr = "";
    my $list      = "password";

    if ( lc $cmd eq 'password' ) {
        if ( int @val == 1 ) {
            return storePassword( $hash, $val[0] );
        }
    }
    return "Unknown argument $cmd or wrong parameter(s), choose one of $list";
}    # end Set

#####################################
# checks and stores VBUS password used for telnet connection
sub storePassword() {
    my $hash = shift;
    my $password = shift;
    my $index = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
    my $key   = getUniqueId() . $index;
    my $enc_pwd = "";
    $key = Digest::MD5::md5_hex( unpack "H*", $key );
    $key .= Digest::MD5::md5_hex($key);

    for my $char ( split //, $password ) {
        my $encode = chop($key);
        $enc_pwd .= sprintf( "%.2x", ord($char) ^ ord($encode) );
        $key = $encode . $key;
    }

    my $err = setKeyValue( $index, $enc_pwd );
    return "error while saving the password - $err" if ( defined($err) );

    return "password successfully saved";
}    # end storePassword
#####################################
#####################################
# reads the VBUS password
sub readPassword() {
    my $hash = shift;
    my $name = $hash->{NAME};
    my $index = $hash->{TYPE} . "_" . $hash->{NAME} . "_passwd";
    my $key   = getUniqueId() . $index;
    my ( $password, $err );

    Log3 $hash, 5, "Read VBUS password from file";
    ( $err, $password ) = getKeyValue($index);

    if ( defined($err) ) {
        Log3 $hash, 4, "unable to read VBUS password from file: $err";
        return;
    }

    if ( defined($password) ) {
        $key = Digest::MD5::md5_hex( unpack "H*", $key );
        $key .= Digest::MD5::md5_hex($key);
        my $dec_pwd = '';

        for my $char ( map { pack( 'C', hex($_) ) } ( $password =~ /(..)/g ) ) {
            my $decode = chop($key);
            $dec_pwd .= chr( ord($char) ^ ord($decode) );
            $key = $decode . $key;
        }

        return $dec_pwd;
    }
    else {
        Log3 $hash, 4, "No password in file";
        return;
    }
}    # end VBUS_readPassword

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
  <a name="Define"></a>
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
