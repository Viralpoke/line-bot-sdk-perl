package LINE::Bot::API::Client::Furl;
use strict;
use warnings;

use Carp qw/ carp croak/;
use File::Temp;
use Furl::HTTP;
use JSON::XS;

use LINE::Bot::API;
use LINE::Bot::API::Client;

our @CARP_NOT = qw( LINE::Bot::API::Client::Furl LINE::Bot::API::Client LINE::Bot::API);
my $JSON = JSON::XS->new->utf8;

sub new {
    my($class, %args) = @_;

    $args{http_client}          ||= +{};
    $args{http_client}{agent}   ||= "LINE::Bot::API/$LINE::Bot::API::VERSION";
    $args{http_client}{timeout} ||= 3;
    bless {
        channel_id     => $args{channel_id},
        channel_secret => $args{channel_secret},
        channel_mid    => $args{channel_mid},
        furl           => Furl::HTTP->new(
            %{ $args{http_client} }
        ),
    }, $class;
}

sub credentials {
    my $self = shift;
    (
        'X-Line-ChannelID'             => $self->{channel_id},
        'X-Line-ChannelSecret'         => $self->{channel_secret},
        'X-Line-Trusted-User-With-ACL' => $self->{channel_mid},
    );
}

sub get {
    my($self, $url) = @_;

    my($res_minor_version, $res_status, $res_msg, $res_headers, $res_content) = $self->{furl}->get(
        $url,
        [
            $self->credentials,
        ],
    );
    unless ($res_content && $res_content =~ /^\{.+\}$/) {
        croak 'LINE BOT API error: ' . $res_content;
    }

    $JSON->decode($res_content);
}

sub post {
    my($self, $url, $data) = @_;

    my $json = $JSON->encode($data);
    my($res_minor_version, $res_status, $res_msg, $res_headers, $res_content) = $self->{furl}->post(
        $url,
        [
            $self->credentials,
            'Content-Type'   => 'application/json; charset=UTF-8',
            'Content-Length' => length($json),
        ],
        $json,
    );
    unless ($res_content && $res_content =~ /^\{.+\}$/) {
        croak 'LINE BOT API error: ' . $res_content;
    }

    my $ret = $JSON->decode($res_content);
    $ret->{http_status} = $res_status;
    $ret;
}

sub contents_download {
    my($self, $url, %options) = @_;

    my $fh = delete($options{fh}) || File::Temp->new(%options);

    my($res_minor_version, $res_status, $res_msg, $res_headers, $res_content) = $self->{furl}->request(
        method     => 'GET',
        url        => $url,
        write_file => $fh,
        headers    => [
            $self->credentials,
        ],
    );
    unless ($res_status eq '200') {
        carp "LINE BOT API contents_download error: $res_status $url\n\tcontent=$res_content";
        return;
    }

    ($fh, $res_headers);
}

1;
