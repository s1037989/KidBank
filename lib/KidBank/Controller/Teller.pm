package KidBank::Controller::Teller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::Collection qw(c);

sub balance ($self) {
  my $balance = $self->tx_log
    ->map(sub{{date => $self->now($_->{date})->ymd, amount => $_->{pennies} / 100}})
    ->reduce(sub{$a->{$b->{date}} += $b->{amount}; $a}, {});
  my $_balance = 0;
  $balance = c(map { {date => $_, amount => $_balance += $balance->{$_}} } sort keys %$balance);
  $self->respond_to(
    any => {inline => '<pre><%= dumper $balance %></pre>', balance => $balance},
    json => {json => $balance},
  );
}

sub remove_tx ($self) {
  warn $self->param('id');
  $self->db->delete('transactions', {username => $self->session('username'), id => $self->param('id')});
  $self->flash(message => 'deleted!')->redirect_to('welcome');
}

sub welcome ($self) {
  $self->render(items_per_page => 3);
}

sub write_tx ($self) {
  my $v = $self->validation;
  return $self->render(action => 'welcome') unless $v->has_data;

  # Validate parameters ("pass_again" depends on "pass")
  $v->required('date');
  $v->required('tx_with');
  $v->required('pennies')->money;
  $v->required('memo');

  # Check if validation failed
  return $self->flash(error => Mojo::JSON::j([map { $v->error($_) } @{$v->failed}]))->render(action => 'welcome') if $v->has_error;

  $v->output->{date} = Time::Piece->strptime($v->param('date'), '%Y-%m-%d')->epoch;
  $v->output->{pennies} = $v->param('pennies') * 100;
  $self->db->insert('transactions' => {username => $self->session('username'), map { $_ => $v->param($_) } qw(date tx_with pennies memo)}, {returning => 'id'});
  $self->redirect_to('welcome');
}

1;