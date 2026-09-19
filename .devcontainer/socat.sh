#!/usr/bin/bash

socat TCP-LISTEN:${TCP_PORT},reuseaddr,fork EXEC:"/usr/local/bin/zls"
