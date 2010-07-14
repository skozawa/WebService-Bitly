package WebService::Bitly;

use warnings;
use strict;
use Carp;
use UNIVERSAL::require;

our $VERSION = '0.01';

use URI;
use URI::QueryParam;
use LWP::UserAgent;
use JSON;

use WebService::Bitly::Result::HTTPError;
use WebService::Bitly::Result::Authenticate;

use base qw(Class::Accessor::Fast);

__PACKAGE__->mk_accessors(qw(
    user_name
    user_api_key
    end_user_name
    end_user_api_key
    domain
    version

    base_url
    ua
));

sub new {
    my ($class, %args) = @_;
    if (!defined $args{user_name} || !defined $args{user_api_key}) {
        croak("user_name and user_api_key are both required parameters.\n");
    }

    $args{version} ||= 'v3';
    $args{ua} = LWP::UserAgent->new(
        env_proxy => 1,
        timeout   => 30,
    );
    $args{base_url} ||= 'http://api.bit.ly/';

    return $class->SUPER::new(\%args);
}

sub shorten {
    my ($self, $url) = @_;
    if (!defined $url) {
        croak("url is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/shorten");
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(x_login  => $self->end_user_name)    if $self->end_user_name;
       $api_url->query_param(x_apiKey => $self->end_user_api_key) if $self->end_user_api_key;
       $api_url->query_param(domain   => $self->domain)           if $self->domain;
       $api_url->query_param(format   => 'json');
       $api_url->query_param(longUrl  => $url);

    $self->_do_request($api_url, 'Shorten');
}

sub expand {
    my ($self, %args) = @_;
    my $short_urls = $args{short_urls} || [];
    my $hashes     = $args{hashes} || [];
    if (!$short_urls && !$hashes) {
        croak("either short_urls or hashes is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/expand");
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(format   => 'json');
       $api_url->query_param(shortUrl => reverse(@$short_urls))   if $short_urls;
       $api_url->query_param(hash     => reverse(@$hashes))       if $hashes;

    $self->_do_request($api_url, 'Expand');
}

sub validate {
    my ($self) = @_;

    my $api_url = URI->new($self->base_url . $self->version . "/validate");
       $api_url->query_param(format   => 'json');
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(x_login  => $self->end_user_name);
       $api_url->query_param(x_apiKey => $self->end_user_api_key);

    $self->_do_request($api_url, 'Validate');
}

sub set_end_user_info {
    my ($self, $end_user_name, $end_user_api_key) = @_;

    if (!defined $end_user_name || !defined $end_user_api_key) {
        croak("end_user_name and end_user_api_key are both required parameters.\n");
    }

    $self->end_user_name($end_user_name);
    $self->end_user_api_key($end_user_api_key);

    return $self;
}

sub clicks {
    my ($self, %args) = @_;
    my $short_urls   = $args{short_urls} || [];
    my $hashes       = $args{hashes} || [];
    if (!$short_urls && !$hashes) {
        croak("either short_urls or hashes is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/clicks");
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(format   => 'json');
       $api_url->query_param(shortUrl => reverse(@$short_urls))   if $short_urls;
       $api_url->query_param(hash     => reverse(@$hashes))       if $hashes;

    $self->_do_request($api_url, 'Clicks');
}

sub bitly_pro_domain {
    my ($self, $domain) = @_;
    if (!$domain) {
        croak("domain is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/bitly_pro_domain");
       $api_url->query_param(format   => 'json');
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(domain   => $domain);

    $self->_do_request($api_url, 'BitlyProDomain');
}

sub lookup {
    my ($self, $urls) = @_;
    if (!$urls) {
        croak("urls is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/lookup");
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(format   => 'json');
       $api_url->query_param(url      => reverse(@$urls));

    $self->_do_request($api_url, 'Lookup');
}

sub authenticate {
    my ($self, $end_user_name, $end_user_password) = @_;

    my $api_url = URI->new($self->base_url . $self->version . "/authenticate");

    my $response = $self->ua->post($api_url, [
        format     => 'json',
        login      => $self->user_name,
        apiKey     => $self->user_api_key,
        x_login    => $end_user_name,
        x_password => $end_user_password,
    ]);

    if (!$response->is_success) {
        return WebService::Bitly::Result::HTTPError->new({
            status_code => $response->code,
            status_txt  => $response->message,
        });
    }

    my $bitly_response = from_json($response->{_content});
    return WebService::Bitly::Result::Autenticate->new($bitly_response);
}

sub info {
    my ($self, %args) = @_;
    my $short_urls   = $args{short_urls} || [];
    my $hashes       = $args{hashes} || [];
    if (!$short_urls && !$hashes) {
        croak("either short_urls or hashes is required parameter.\n");
    }

    my $api_url = URI->new($self->base_url . $self->version . "/info");
       $api_url->query_param(login    => $self->user_name);
       $api_url->query_param(apiKey   => $self->user_api_key);
       $api_url->query_param(format   => 'json');
       $api_url->query_param(shortUrl => reverse(@$short_urls))   if $short_urls;
       $api_url->query_param(hash     => reverse(@$hashes))       if $hashes;

    $self->_do_request($api_url, 'Info');
}

sub _do_request {
    my ($self, $url, $result_class) = @_;

    my $response = $self->ua->get($url);

    if (!$response->is_success) {
        return WebService::Bitly::Result::HTTPError->new({
            status_code => $response->code,
            status_txt  => $response->message,
        });
    }

    $result_class = 'WebService::Bitly::Result::' . $result_class;
    $result_class->require;

    my $bitly_response = from_json($response->{_content});
    return $result_class->new($bitly_response);
}

1;

__END__;

=head1 NAME

WebService::Bitly - A Perl interface to the bit.ly API

=head1 VERSION

This document describes version 0.01 of WebService::Bitly.

=head1 SYNOPSIS

    use WebService::Bitly;

    my $bitly = WebService::Bitly->new(
        user_name => 'shibayu',
        user_api_key => 'R_1234567890abcdefg',
    );

    my $shorten = $bitly->shorten('http://example.com/');
    if ($shorten->is_error) {
        warn $shorten->status_code;
        warn $shorten->status_txt;
    }
    else {
        my $short_url = $shorten->short_url;
    }

=head1 DESCRIPTION

WebService::Bitly provides an interface to the bit.ly API.

To get information about bit.ly API, see http://code.google.com/p/bitly-api/wiki/ApiDocumentation.

=head1 METHODS

=head2 new(%param)

Create a new WebService::Bitly object with hash parameter.

    my $bitly = WebService::Bitly->new(
        user_name        => 'shibayu36',
        user_api_key     => 'R_1234567890abcdefg',
        end_user_name    => 'bitly_end_user',
        end_user_api_key => 'R_abcdefg123456789',
        domain           => 'j.mp',
    );

Set up initial state by following parameters.

=over 4

=item * user_name

Required parameter.  bit.ly user name.

=item * user_api_key

Required parameter.  bit.ly user api key.

=item * end_user_name

Optional parameter.  bit.ly end-user name.  This parameter is used by shorten and validate method.

=item * end_user_api_key

Optional parameter.  bit.ly end-user api key.  This parameter is used by shorten and validate method.

=item * domain

Optional parameter.  Specify 'j.mp', if you want to use j.mp domain in shorten method.

=back

=head2 shorten($url)

Get shorten result by long url.  you can make requests on behalf of another bit.ly user,  if you specify end_user_name and end_user_api_key in new or set_end_user_info method.

    my $shorten = $bitly->shorten('http://example.com');
    if (!$shorten->is_error) {
        print $shorten->short_url;
        print $shorten->hash;
    }

You can get data by following method of result object.

=over 4

=item * is_error

return 1, if request is failed.

=item * short_url

=item * is_new_hash

return 1, if specified url was shortened first time.

=item * hash

=item * global_hash

=item * long_url

=back

=head2 expand(%param)

Get long URL by given bit.ly URL or hash (or multiple).

    my $expand = $bitly->expand(
        short_urls => ['http://bit.ly/abcdef', 'http://bit.ly/fedcba'],
        hashes     => ['123456', '654321'],
    );
    if (!$expand->is_error) {
        for $result ($expand->results) {
            print $result->long_url if !$result->is_error;
        }
    }

You can get expand result list by $expand->results method.  Each result object has following method.

=over 4

=item * short_url

=item * hash

=item * user_hash

=item * global_hash

=item * long_url

=item * is_error

return error message, if error occured.

=back

=head2 validate

Validate end-user name and end-user api key, which are specified by new or set_end_user_info method.

    $bitly->set_end_user_info('end_user', 'R_1234567890123456');
    print $bitly->end_user_name;    # 'end_user'
    print $bitly->end_user_api_key; # 'R_1234567890123456'
    if ($bitly->validate->is_valid) {
        ...
    }

=head2 set_end_user_info($end_user_name, $end_user_api_key)

Set end-user name and end-user api key.

=head2 clicks(%param)

Get the statistics about the clicks, given bit.ly URL or hash (or multiple).
You can use this in much the same way as expand method.  Each result object has following method.

=over 4

=item * short_url

=item * hash

=item * user_hash

=item * global_hash

=item * user_clicks

=item * global_clicks

=item * is_error

=back

=head2 bitly_pro_domain($domain)

Check whether a given short domain is assigned for bitly.Pro.

    my $result = $bitly->bitly_pro_domain('nyti.ms');
    if ($result->is_pro_domain) {
        ...
    }

=head2 lookup([@urls])
Get shortened url information by given urls.

    my $lookup = $bitly->lookup([
        'http://code.google.com/p/bitly-api/wiki/ApiDocumentation',
        'http://betaworks.com/',
    ]);
    if (!$lookup->is_error) {
        for my $result ($lookup->results) {
            print $result->short_url;
        }
    }

Each result object has following method.

=over 4

=item * global_hash

=item * short_url

=item * url

=item * is_error

return error message, if error occured by this url.

=back

=head2 info(%param)

Get detail page information by given bit.ly URL or hash (or multiple).
You can use this in much the same way as expand method.  Each result object has following method.

=over 4

=item * short_url

=item * hash

=item * user_hash

=item * global_hash

=item * title

page title.

=item * created_by

the bit.ly username that originally shortened this link.

=item * is_error

return error message, if error occured by this url.

=back

=head2 authenticate($end_user_name, $end_user_password)

Lookup a bit.ly API key by given end-user name and end-user password.  However, this method is restricted.  See bit.ly api documentation, learning more.

    my $result = $bitly->authenticate('bitlyapidemo', 'good-password');
    if ($result->is_success) {
        print $result->user_name;
        print $result->api_key;
    }

=head1 SEE ALSO

=over 4

=item * bit.ly API Documentation

http://code.google.com/p/bitly-api/wiki/ApiDocumentation

=back

=head1 REPOSITORY

http://github.com/shiba-yu36/WebService-Bitly

=head1 AUTHOR

Yuki Shibazaki, C<< <shiba1029196473 at gmail.com> >>

=head1 COPYRIGHT AND LICENSE

Copyright 2010 Yuki Shibazaki.

WebService::Bitly is free software; you may redistribute it and/or modify it under the same terms as Perl itself.
