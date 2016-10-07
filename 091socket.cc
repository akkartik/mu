:(before "End Includes")
#include <unistd.h>
#include <sys/socket.h>
#include <netinet/in.h>

:(before "End Types")
struct socket_t {
  int fd;
  sockaddr_in addr;
  socket_t() {
    fd = 0;
    bzero(&addr, sizeof(addr));
  }
};

:(before "End Primitive Recipe Declarations")
_SOCKET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$socket", _SOCKET);
:(before "End Primitive Recipe Checks")
case _SOCKET: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$socket' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$socket' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$socket' requires exactly one product, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$socket' should be a number (file handle), but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _SOCKET: {
  int port = ingredients.at(0).at(0);
  socket_t* server = server_socket(port);
  products.resize(1);
  if (server->fd < 0) {
    delete server;
    products.at(0).push_back(0);
    break;
  }
  long long int result = reinterpret_cast<long long int>(server);
  products.at(0).push_back(static_cast<double>(result));
  break;
}
:(code)
socket_t* server_socket(int portno) {
  socket_t* result = new socket_t;
  result->fd = socket(AF_INET, SOCK_STREAM, 0);
  int dummy = 0;
  setsockopt(result->fd, SOL_SOCKET, SO_REUSEADDR, &dummy, sizeof(dummy));
  result->addr.sin_family = AF_INET;
  result->addr.sin_addr.s_addr = INADDR_ANY;
  result->addr.sin_port = htons(portno);
  if (bind(result->fd, reinterpret_cast<sockaddr*>(&result->addr), sizeof(result->addr)) >= 0) {
    listen(result->fd, /*queue length*/5);
  }
  else {
    close(result->fd);
    result->fd = -1;
    raise << "Failed to bind result socket to port " << portno << ". Something's already using that port.\n" << end();
  }
  return result;
}

:(before "End Primitive Recipe Declarations")
_ACCEPT,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$accept", _ACCEPT);
:(before "End Primitive Recipe Checks")
case _ACCEPT: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$accept' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$accept' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$accept' requires exactly one product, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$accept' should be a number (file handle), but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _ACCEPT: {
  products.resize(2);
  products.at(1).push_back(ingredients.at(0).at(0));  // indicate it modifies its ingredient
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  socket_t* server = reinterpret_cast<socket_t*>(x);
  if (server) {
    socket_t* session = accept_session(server);
    long long int result = reinterpret_cast<long long int>(session);
    products.at(0).push_back(static_cast<double>(result));
  }
  else {
    products.at(0).push_back(0);
  }
  break;
}
:(code)
socket_t* accept_session(socket_t* server) {
  if (server->fd == 0) return NULL;
  socket_t* result = new socket_t;
  socklen_t dummy = sizeof(result->addr);
  result->fd = accept(server->fd, reinterpret_cast<sockaddr*>(&result->addr), &dummy);
  return result;
}

:(before "End Primitive Recipe Declarations")
_READ_FROM_SOCKET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$read-from-socket", _READ_FROM_SOCKET);
:(before "End Primitive Recipe Checks")
case _READ_FROM_SOCKET: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-socket' requires exactly two ingredients, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$read-from-socket' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second ingredient of '$read-from-socket' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-socket' requires exactly two product, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _READ_FROM_SOCKET: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  int bytes = static_cast<int>(ingredients.at(1).at(0)); //? Should this be something with more bytes?
  socket_t* socket = reinterpret_cast<socket_t*>(x);
  int socket_fd = socket->fd;
  char contents[bytes];
  bzero(contents, bytes);
  int bytes_read = read(socket_fd, contents, bytes - 1 /* null-terminated */);
//?   cerr << "Read:\n" << string(contents) << "\n";
  products.resize(2);
  products.at(0).push_back(new_mu_text(string(contents)));
  products.at(1).push_back(bytes_read);
  break;
}

:(before "End Primitive Recipe Declarations")
_WRITE_TO_SOCKET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$write-to-socket", _WRITE_TO_SOCKET);
:(before "End Primitive Recipe Checks")
case _WRITE_TO_SOCKET: {
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$write-to-socket' requires exactly two ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _WRITE_TO_SOCKET: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  socket_t* session = reinterpret_cast<socket_t*>(x);
  // Write one character to a session at a time.
  long long int y = static_cast<long long int>(ingredients.at(1).at(0));
  char c = static_cast<char>(y);
  if (write(session->fd, &c, 1) != 1) {
    raise << maybe(current_recipe_name()) << "failed to write to socket\n" << end();
    exit(0);
  }
  long long int result = reinterpret_cast<long long int>(session);
  products.resize(1);
  products.at(0).push_back(result);
  break;
}

:(before "End Primitive Recipe Declarations")
_CLOSE_SOCKET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$close-socket", _CLOSE_SOCKET);
:(before "End Primitive Recipe Checks")
case _CLOSE_SOCKET: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$close-socket' requires exactly two ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$close-socket' should be a character, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _CLOSE_SOCKET: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  socket_t* socket = reinterpret_cast<socket_t*>(x);
  close(socket->fd);
  break;
}
