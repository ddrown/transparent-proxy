package TransProxy::Connection;

use strict;
use Socket;
use Socket6;
use IO::Socket::Socks;

sub new {
  my ($class,$local_socket) = @_;

  my $self = {
    local_socket => $local_socket,
    socks_ip => "127.0.0.1", # TODO
    socks_port => undef,
    v4 => undef,
    v4_port => undef,
    socks_client => undef,
    SOCKS_STATE => undef,
  };

  bless $self, $class;

  $self->_new_local_socket();
  $self->_socks_connect();

  return $self;
}

sub client {
  my($self) = @_;
  return($self->{local_socket}->peerhost(),$self->{local_socket}->peerport());
}

sub server {
  my($self) = @_;
  return($self->{v4},$self->{v4_port});
}

sub socks_client {
  my($self) = @_;
  return $self->{socks_client};
}

sub local_socket {
  my($self) = @_;
  return $self->{local_socket};
}

# returns true when writes are done
sub socks_stage_write {
  my($self) = @_;
  my $state = $self->{socks_client}->ready();
  $self->{SOCKS_STATE} = $SOCKS_ERROR->as_str();
  return $SOCKS_ERROR->as_num() == SOCKS_WANT_READ;
}

# returns true when the client is ready
sub socks_stage_read {
  my($self) = @_;
  my $state = $self->{socks_client}->ready();
  $self->{SOCKS_STATE} = $SOCKS_ERROR->as_str();
  if($SOCKS_ERROR->as_num() != SOCKS_WANT_READ and $SOCKS_ERROR->as_num() > 0) {
    return -1;
  }
  return $state;
}

sub socks_error {
  my($self) = @_;
  return $self->{SOCKS_STATE};
}

sub xfer {
  my($self,$fh) = @_;
  my($data,$other_fh,$connection_side);

  if($fh == $self->{socks_client}) {
    $other_fh = $self->{local_socket};
    $connection_side = "remote";
  } elsif($fh == $self->{local_socket}) {
    $other_fh = $self->{socks_client};
    $connection_side = "local";
  } else {
    die("unknown fh $fh passed to connection");
  }

  if(sysread($fh, $data, 4096) <= 0) {
    return 1; # TODO: shutdown other end
  }
  # TODO: better error detection (blocked, one way)
  print $other_fh $data;
  return 0;
}

sub socks_port {
  my($self) = @_;
  return $self->{socks_port};
}

sub _socks_connect {
  my($self) = @_;

  $self->{socks_client} = IO::Socket::Socks->new(
		ProxyAddr   => $self->{socks_ip},
		ProxyPort   => $self->{socks_port},
		ConnectAddr => $self->{v4},
		ConnectPort => $self->{v4_port},
		Blocking => 0,
		) or die $SOCKS_ERROR;
  $self->{SOCKS_STATE} = $SOCKS_ERROR->as_str();
}

sub _new_local_socket {
  my($self) = @_;

  my $SOL_IPV6 = 41;
  my $SO_ORIGINAL_DST = 80;
  my $packed = getsockopt($self->{local_socket}, $SOL_IPV6, $SO_ORIGINAL_DST) or die "getsockopt SO_ORIGINAL_DST $!";
  my ($host, $port) = getnameinfo($packed, NI_NUMERICHOST | NI_NUMERICSERV);
  my $v4_raw = substr($packed,20,4);
  my $socks_port_raw = substr($packed,18,2);
  $self->{socks_port} = unpack("n",$socks_port_raw);
  $self->{v6} = $host;
  $self->{v4} = inet_ntop(AF_INET, $v4_raw);
  $self->{v4_port} = $port;

  $self->{local_socket}->blocking(0);
}

1;
