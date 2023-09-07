package KidBank;
use Mojo::Base 'Mojolicious', -signatures;

use Locale::Currency::Format;
use Mojo::SQLite;
use Time::Piece;

# This method will run once at server start
sub startup ($self) {
  my $config = $self->plugin('Config');
  $self->sessions->default_expiration(86400 * 7);
  $self->secrets($config->{secrets} || [$self->moniker]);

  # Select the library version
  my $sql = Mojo::SQLite->new('sqlite:kid_bank.db');
  $sql->migrations->name('bank')->from_file('migrations/kid_bank.sql')->migrate;
  
  $self->plugin('Pager' => {always_show_prev_next => 1});

  $self->helper(pager_text => sub ($c, $page=undef) {
    sub { $page->{prev} ? 'Prev' : $page->{next} ? 'Next' : $page->{n} };
  });
  $self->helper(db => sub ($c) { state $db = $sql->db });
  $self->helper(now => sub ($c, $date=undef) { $date ? localtime($date) : localtime });
  $self->helper(currency => sub ($c, $value) { _usd($value) });
  $self->helper(balance => sub ($c) {
    my $balance = $c->db->select('transactions', [\'sum(pennies)'], {username => $c->session('username')})->array->[0];
    return $balance ? $balance / 100 : 0;
  });
  $self->helper(tx_log => sub ($c, $page=undef, $items_per_page=undef) {
    $page = $page || $c->param('page') || 1;
    my $items = $c->db->select('transactions', undef, {username => $c->session('username')}, {order_by => 'date'})->hashes;
    my $total_items = $items->size;
    $items = $c->db->select('transactions', undef, {username => $c->session('username')}, {order_by => 'date', limit => $items_per_page, offset => ($page-1) * $items_per_page})->hashes if $page && $items_per_page;
    return ($total_items, $items);
  });

  $self->validator->add_check(money => sub ($v, $name, $value) {
    return !($value =~ /^[+-]?[0-9]{1,3}(?:,?[0-9]{3})*(?:\.[0-9]{1,2})?$/);
  });

  # Router
  my $r = $self->routes;
  $r->get('/open')->to('bank#open_account')->name('open_account');
  $r->post('/open')->to('bank#create_account')->name('create_account');
  $r->get('/login')->to('bank#login');
  $r->get('/logout')->to('bank#logout');
  $r->post('/login')->to('bank#post_login');

  my $auth = $r->under('/')->to('bank#auth');
  $auth->get('/')->to('teller#welcome')->name('welcome');
  $auth->websocket('/tx')->to('teller#transactions')->name('tx_log');
  $auth->get('/balance' => [format => ['html', 'json']] => {format => 'html'})->to('teller#balance');
  $auth->delete('/tx/:id')->to('teller#remove_tx')->name('remove_tx');
  $auth->post('/tx')->to('teller#write_tx')->name('write_tx');
}

sub _currency_set {
  Locale::Currency::Format::currency_set('USD', '$#,###.##', FMT_COMMON); FMT_COMMON
}

sub _usd { $#_ == 0 ? Locale::Currency::Format::currency_format('USD', pop, _currency_set) : '' }

1;
