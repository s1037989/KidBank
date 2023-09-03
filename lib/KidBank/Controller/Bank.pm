package KidBank::Controller::Bank;
use Mojo::Base 'Mojolicious::Controller', -signatures;

sub auth ($self) {
  return 1 if $self->session('username');
  $self->redirect_to('login');
  return undef;
}

sub create_account ($self) {
  my $v = $self->validation;
  return $self->render('open_account') unless $v->has_data;

  # Validate parameters ("pass_again" depends on "pass")
  $v->required('name');
  $v->required('username')->size(1, 20)->like(qr/^[a-z0-9]+$/);
  $v->optional('password')->size(1, 500);
  $v->required('password2')->equal_to('password');

  # Check if validation failed
  return $self->flash(error => Mojo::JSON::j([map { $v->error($_) } @{$v->failed}]))->render('open_account') if $v->has_error;

  my $opened;
  eval {
    $opened = $self->db->insert('users', {map { $_ => $v->param($_) } qw(name username password)}, {returning => 'username'});
  };
  return $self->render('open_account', error => 'failed to open an account') unless $opened;
  $self->flash(message => 'opened an account!')->redirect_to('login');
}

sub logout { shift->session(expires => 1)->redirect_to('login') }

sub post_login ($self) {
  my $login = $self->db->select('users', ['username', 'name'], {map { $_ => $self->param($_) } qw(username password)})->hash;
  return $self->flash(error => 'wrong')->redirect_to('login') unless $login;
  $self->session($login)->redirect_to('/');
}

1;