#include <ei.h>

#include <sys/socket.h>
#include <arpa/inet.h>
#include <unistd.h>
#include <stdio.h>

static int listen_sock(int *listen_fd, int *port) {
  int fd = socket(AF_INET, SOCK_STREAM, 0);
  if (fd < 0) {
    return 1;
  }

  int opt_on = 1;
  if (setsockopt(fd, SOL_SOCKET, SO_REUSEADDR, &opt_on, sizeof(opt_on))) {
    return 1;
  }

  struct sockaddr_in addr;
  unsigned int addr_size = sizeof(addr);
  addr.sin_family = AF_INET;
  addr.sin_port = htons(0);
  addr.sin_addr.s_addr = htonl(INADDR_ANY);

  if (bind(fd, (struct sockaddr *)&addr, addr_size) < 0) {
    return 1;
  }

  if (getsockname(fd, (struct sockaddr *)&addr, &addr_size)) {
    return 1;
  }
  *port = (int)ntohs(addr.sin_port);

  const int queue_size = 5;
  if (listen(fd, queue_size)) {
    return 1;
  }

  *listen_fd = fd;
  return 0;
}

int main(int argc, char **argv) {
  ei_init();
  short creation = 1;

  // Declare variables
  int socket_fd;
  ei_cnode node;
  char* hostname = "127.0.0.1";
  char* cnode_name = "c@127.0.0.1";
  char* cookie = "SECRET_COOKIE";

  // Initialize the connection
  struct in_addr addr;
  addr.s_addr = inet_addr("127.0.0.1");
  if (ei_connect_xinit(&node, hostname, "c", cnode_name, &addr,
                       cookie, creation) < 0) {
    fprintf(stderr, "init error\n");
    return 1;
  }
  fprintf(stderr, "initialized %s (%s)\n", ei_thisnodename(&node), inet_ntoa(addr));

  int port;
  int listen_fd = -1;
  // if (listen_sock(&listen_fd, &port)) {
  //   fprintf(stderr, "Error initializing listen\n");
  //   return 1;
  // }
  // if((listen_fd = ei_listen(&node, &port, 10)) == -1) {
  //   fprintf(stderr, "Error initializing listen\n");
  //   return 1;
  // }
  if((listen_fd = ei_xlisten(&node, &addr, &port, 10)) < 0) {
    fprintf(stderr, "Error initializing listen\n");
    return 1;
  }
  fprintf(stderr, "listening at %d\n", port);

  int pub;
  pub = ei_publish(&node, port);

  ErlConnect conn;
  int accept_fd = ERL_ERROR;
  accept_fd = ei_accept_tmo(&node, listen_fd, &conn, 5000);
  if (accept_fd == ERL_ERROR) {
    fprintf(stderr, "accept error");
    return 1;
  }
  fprintf(stderr, "accepted %s\n", conn.nodename);

  // Connect to a node
  // if ((socket_fd = ei_connect(&node, "iex@127.0.0.1")) == -1) {
  //   fprintf(stderr, "Error connecting to node\n");
  //   return 1;
  // }

  ei_x_buff buf;
  ei_x_new_with_version(&buf);

  ei_x_encode_tuple_header(&buf, 2);
  ei_x_encode_pid(&buf, ei_self(&node));
  ei_x_encode_atom(&buf, "Hello world");

  ei_reg_send(&node,accept_fd,"console",buf.buff,buf.index);

  for(;;) {
  ei_x_buff in_buff;
  ei_x_new(&in_buff);
  erlang_msg emsg;
  int res = 0;
  switch (ei_xreceive_msg_tmo(accept_fd, &emsg, &in_buff, 100)) {
  case ERL_TICK:
    fprintf(stderr, "ERL_TICK\n");
    break;
  case ERL_ERROR:
    if(erl_errno != ETIMEDOUT)
      fprintf(stderr, "ERL_ERROR: %d\n", erl_errno);
    // res = erl_errno != ETIMEDOUT;
    break;
  default:
    fprintf(stderr, "got message\n");
    if (emsg.msgtype == ERL_REG_SEND) {
      // env->reply_to = &emsg.from;
      int index = 0;
      int version;
      ei_decode_version(in_buff.buff, &index, &version);

      int arity;
      ei_decode_tuple_header(in_buff.buff, &index, &arity);

      char fun_name[2048];
      ei_decode_atom(in_buff.buff, &index, fun_name);

      break;
    }
  }
  ei_x_free(&in_buff);
  }
  while(1 == 1) {
    if(getc(stdin)) break;
  }

  // Use the connection
  // ...

  // Close the connection
  if (ei_close_connection(accept_fd) == -1) {
    fprintf(stderr, "Error closing connection\n");
    return 1;
  }

  return 0;
}
