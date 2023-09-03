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
  
  $self->helper(db => sub ($c) { state $db = $sql->db });
  $self->helper(now => sub ($c, $date=undef) { $date ? localtime($date) : localtime });
  $self->helper(currency => sub ($c, $value) { _usd($value) });
  $self->helper(balance => sub ($c) {
    my $balance = $c->db->select('transactions', [\'sum(pennies)'], {username => $c->session('username')})->array->[0];
    return $balance ? $balance / 100 : 0;
  });
  $self->helper(tx_log => sub ($c) { $c->db->select('transactions', undef, {username => $c->session('username')}, {order_by => 'date'})->hashes });

  $self->validator->add_check(money => sub ($v, $name, $value) {
    $value =~ s/[^\d\.]//g;
    return !($value =~ /^\d+(\.\d{2})?$/);
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
  $auth->get('/balance' => [format => ['html', 'json']] => {format => 'html'})->to('teller#balance');
  $auth->delete('/tx/:id')->to('teller#remove_tx')->name('remove_tx');
  $auth->post('/tx')->to('teller#write_tx')->name('write_tx');
}

sub _currency_set {
  Locale::Currency::Format::currency_set('USD', '$#,###.##', FMT_COMMON); FMT_COMMON
}

sub _usd { $#_ == 0 ? Locale::Currency::Format::currency_format('USD', pop, _currency_set) : '' }

1;
