package KidBank::Controller::Teller;
use Mojo::Base 'Mojolicious::Controller', -signatures;

use Mojo::Collection qw(c);

sub balance ($self) {
  my ($total_items, $tx_log) = $self->tx_log;
  my $balance = $tx_log
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

sub transactions ($self) {
  my $items_per_page = 3;
  $self->on(json => sub ($c, $json) {
    my ($total_items, $tx_log) = $c->tx_log($json->{page}, $items_per_page);
    my $pages = int($total_items / $items_per_page) + ($total_items % $items_per_page);
    $c->send({json => {page => $json->{page}, pages => $pages, html => $c->render_to_string('teller/tx_log', tx_log => $tx_log)}});
  });
}

sub welcome ($self) {
  $self->render(items_per_page => 3);
}

sub write_tx ($self) {
  my $v = $self->validation;
  return $self->render(action => 'welcome') unless $v->has_data;

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