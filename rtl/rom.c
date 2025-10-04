#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>

unsigned char data[64*1024];

void usage()
{
    fprintf(stderr, "usage: ./rom {0|1} <bin-file\n");
    exit(1);
}

int main(int argc, char *argv[])
{
  int ret, low = 0, a = 0, wide = 0;
    if (argc != 2) usage();
    if (argv[1][0] == '0') low = 1;
    if (argv[1][0] == '1') low = 0;
    if (argv[1][0] == 'X') wide = 1;
    ret = read(0, data, sizeof(data));
    if (ret > 0) {
      if (!wide) {
        for (int o = low; o < ret; o += 2) {
	  unsigned char b = data[o];
	  printf("    15'h%04x: out = 8'h%02x;\n", a, b);
	  a++;
	}
      } else {
        for (int o = 0; o < ret/2; o++) {
	  unsigned short w = ((unsigned short*)data)[o];
	  printf("    15'h%04x: dout <= 16'h%04x;\n", o, ((w>>8)&0xFF)|((w<<8)&0xFF00));
	}
	
      }
    }
    return 0;
}
	
