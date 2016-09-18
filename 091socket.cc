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

:(code)
void server_socket(int portno, socket_t* server) {
  server->fd = socket(AF_INET, SOCK_STREAM, 0);
  int dummy;
  setsockopt(server->fd, SOL_SOCKET, SO_REUSEADDR, &dummy, sizeof(dummy));
  server->addr.sin_family = AF_INET;
  server->addr.sin_addr.s_addr = INADDR_ANY;
  server->addr.sin_port = htons(portno);
  if (bind(server->fd, (struct sockaddr*)&server->addr, sizeof(server->addr)) < 0) {
    server->fd = -1;
    raise << "Failed to bind server socket to port " << portno << ". Something's already using that port." << "\n";
    return;
  }
  listen(server->fd, 5);
}

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
  socket_t* server = new socket_t();
  server_socket(port, server);
  if (server->fd < 0) {
    break;
  }
  long long int result = reinterpret_cast<long long int>(server);
  products.resize(1);
  products.at(0).push_back(static_cast<double>(result));
  break;
}

:(code)
void session_socket(int serverfd, socket_t* session) {
  socklen_t dummy = sizeof(session->addr);
  session->fd = accept(serverfd, (struct sockaddr*)&session->addr, &dummy);
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
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  socket_t* socket = reinterpret_cast<socket_t*>(x);
  socket_t* session = new socket_t();
  session_socket(socket->fd, session);
  products.resize(2);
  long long int result = reinterpret_cast<long long int>(session);
  products.at(0).push_back(static_cast<double>(result));
  products.at(1).push_back(ingredients.at(0).at(0));
  break;
}

:(before "End Primitive Recipe Declarations")
_READ_FROM_SOCKET,
:(before "End Primitive Recipe Numbers")
put(Recipe_ordinal, "$read-from-socket", _READ_FROM_SOCKET);
:(before "End Primitive Recipe Checks")
case _READ_FROM_SOCKET: {
  if (SIZE(inst.ingredients) != 1) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-socket' requires exactly one ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$read-from-socket' should be a number, but got '" << to_string(inst.ingredients.at(0)) << "'\n" << end();
    break;
  }
  if (SIZE(inst.products) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$read-from-socket' requires exactly one product, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_character(inst.products.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first product of '$read-from-socket' should be a character, but got '" << to_string(inst.products.at(0)) << "'\n" << end();
    break;
  }
  if (!is_mu_boolean(inst.products.at(1))) {
    raise << maybe(get(Recipe, r).name) << "second product of '$read-from-socket' should be a boolean but got '" << to_string(inst.products.at(1)) << "'\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _READ_FROM_SOCKET: {
  long long int x = static_cast<long long int>(ingredients.at(0).at(0));
  socket_t* socket = reinterpret_cast<socket_t*>(x);
  int socket_fd = socket->fd;
  char single_char[2];
  bzero(single_char, 2);
  int bytes_read = read(socket_fd, single_char, 1);
  products.resize(2);
  if (single_char[0]== EOF || bytes_read == 0) {
    products.at(1).push_back(1);  // eof
  }
  else {
    products.at(1).push_back(0);
  }
  products.at(0).push_back(single_char[0]);
  break;
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
  char payload[2] = { c };
  write(session->fd, payload, 1);
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
  if (SIZE(inst.ingredients) != 2) {
    raise << maybe(get(Recipe, r).name) << "'$close-socket' requires exactly two ingredient, but got '" << inst.original_string << "'\n" << end();
    break;
  }
  if (!is_mu_number(inst.ingredients.at(0)) || !is_mu_number(inst.ingredients.at(0))) {
    raise << maybe(get(Recipe, r).name) << "first ingredient of '$close-socket' should be a character, but got '" << to_string(inst.ingredients.at(0)) << "t\n" << end();
    break;
  }
  break;
}
:(before "End Primitive Recipe Implementations")
case _CLOSE_SOCKET: {
  double socket_fd = ingredients.at(0).at(0);
  double session_fd = ingredients.at(1).at(0);
  close(socket_fd);
  close(session_fd);
  break;
}
