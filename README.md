# Seds

<!-- TABLE OF CONTENTS -->
## Table of Contents

- [About The Project](#about-the-project)
  - [Aims](#aims)
  - [Built with](#built-with)
- [Usage](#usage)
  - [q - quit command](#q---quit-command)
  - [p - print command](#p---print-command)
  - [d - delete command](#d---delete-command)
  - [s - substitute command](#s---substitute-command)
  - [-n command line option](#-n-command-line-option)
  - [addresses](#addresses)
  - [Multiple Commands](#multiple-commands)
  - [-f command line option](#-f-command-line-option)
  - [Input Files](#input-files)
  - [Comments & White Space](#comments--white-space)
  - [-i command line option](#-i-command-line-option)
  - [: - label command](#---label-command)
  - [b - branch command](#b---branch-command)
  - [t - conditional branch command](#t---conditional-branch-command)
  - [a - append command](#a---append-command)
  - [i - insert command](#i---insert-command)
  - [c - change command](#c---change-command)
  - [Other Sed Features](#other-sed-features)
- [License](#license)
- [Contact](#contact)

<!-- ABOUT THE PROJECT -->
## About The Project

**Seds** is a simple sed like Unix/Linux tool implementing many sed commands, which is contraction of **sed** **s**ubset.

Seds is a POSIX-compatible subset of sed with extended regular expressions (EREs).

Sed is a very complex program which has many individual commands. I will implement only a few of the most important commands. There will also be a number of simplifying assumptions ([Assumptions](#assumptions)), which make the task easier.

### Aims

* practice in Perl programming generally
* a clear concrete understanding of sed's core semantics

### Built with

* [perl](https://www.perl.org/)

<!-- USAGE EXAMPLES -->
## Usage

### q - quit command

The `Seds q` command causes seds.pl to exit, for example:

```
$ seq 1 5 | ./seds.pl '3q'
1
2
3
$ seq 10 15 | ./seds.pl '/.1/q'
10
11
$seq 500 600 | ./seds.pl '/^.+5$/q'
500
501
502
503
504
505
$ seq 100 1000 | ./seds.pl '/1{3}/q'
100
101
102
103
104
105
106
107
108
109
110
111
```

### p - print command

The `Seds p` commands prints the input line, for example:

```
$ seq 1 5 | ./seds.pl '2p'
1
2
2
3
4
5
$ seq 65 75 | ./seds.pl '/^7/p'
65
66
67
68
69
70
70
71
71
72
72
73
73
74
74
75
75
$ seq 1 5 | ./seds.pl 'p'
1
1
2
2
3
3
4
4
5
5
```

### d - delete command

The `Seds d` commands deletes the input line, for example:

```
$ seq 1 5 | ./seds.pl '4d'
1
2
3
5
$ seq 1 100 | ./seds.pl '/.{2}/d'
1
2
3
4
5
6
7
8
9
$ seq 11 20 | ./seds.pl '/[2468]/d'
11
13
15
17
19
```

### s - substitute command

The `Seds s` command replaces the specified regex on the input line, for example:

```
$ seq 1 5 | ./seds.pl 's/[15]/zzz/'
zzz
2
3
4
zzz
$ seq 10 20 | ./seds.pl 's/[15]/zzz/'
zzz0
zzz1
zzz2
zzz3
zzz4
zzz5
zzz6
zzz7
zzz8
zzz9
20
$ seq 100 111 | ./seds.pl 's/11/zzz/'
100
101
102
103
104
105
106
107
108
109
zzz0
zzz1
```

The substitute command can be followed optionally by the modifier character g, which is the only permitted modifier character. For example:

```
$ echo Hello Andrew | ./seds.pl 's/e//'
Hllo Andrew
$ echo Hello Andrew | ./seds.pl 's/e//g'
Hllo Andrw
```

Just like the other commands, the substitute command can be given addresses to be applied to:

```
$ seq 11 19 | ./seds.pl '5s/1/2/'
11
12
13
14
25
16
17
18
19
$ seq 100 111 | ./seds.pl '/1.1/s/1/-/g'
100
-0-
102
103
104
105
106
107
108
109
110
---
```

Any non-whitespace character may be used to delimit a substitute command, for example:

```
$ seq 1 5 | ./seds.pl 'sX[15]XzzzX'
zzz
2
3
4
zzz
$ seq 1 5 | ./seds.pl 's?[15]?zzz?'
zzz
2
3
4
zzz
$ seq 1 5 | ./seds.pl 's_[15]_zzz_'
zzz
2
3
4
zzz
$ seq 1 5 | ./seds.pl 'sX[15]Xz/z/zX'
z/z/z
2
3
4
z/z/z
```

### -n command line option

The `Seds -n` command line option stops input lines being printed by default, for example:

```
$ seq 1 5 | ./seds.pl -n '3p'
3
$ seq 2 3 20 | ./seds.pl -n '/^1/p'
11
14
17
```

-n command line option is the only useful in conjunction with the p command, but can still be used with the other commands.

### addresses
To make the task harder, $ can be used as an address.

It matches the last line, for example:

```
$ seq 1 5 | ./seds.pl '$d'
1
2
3
4
$ seq 1 10000 | ./seds.pl -n '$p'
10000
```

Seds commands can optionally be preceded by a comma separated pair of address specifying the start and finish of the range of lines the command applies to, for example:

```
$ seq 10 21 | ./seds.pl '3,5d'
10
11
15
16
17
18
19
20
21
$ seq 10 21 | ./seds.pl '3,/2/d'
10
11
21
$ seq 10 21 | ./seds.pl '/2/,4d'
10
11
14
15
16
17
18
19
$ seq 10 21 | ./seds.pl '/1$/,/^2/d'
10
```

Comma separated pairs of address can be used with the p, d, and s commands.

### Multiple Commands

Multiple Seds commands can be supplied separated by semicolons ; or newlines, for example:

```
$ seq 1 5 | ./seds.pl '4q;/2/d'
1
3
4
$ seq 1 5 | ./seds.pl '/2/d;4q'
1
3
4
$ seq 1 20 | ./seds.pl '/2$/,/8$/d;4,6p'
1
9
10
11
19
20
$ seq 1 5 | ./seds.pl '4q
/2/d'
1
3
4
$ seq 1 5 | ./seds.pl '/2/d
4q'
1
3
4
```

Note, semicolons ; and commas , can appear inside Seds commands.

```
$ echo 'Punctuation characters include . , ; :'|./seds.pl 's/;/semicolon/g;/;/q'
Punctuation characters include . , semicolon :
```

### -f command line option

The `Seds -f` reads Seds commands from the specified file, for example:

```
$ echo 4q   >  commands.seds
$ echo /2/d >> commands.seds
$ seq 1 5 | ./seds.pl -f commands.seds
1
3
4
$ echo /2/d >  commands.seds
$ echo 4q   >> commands.seds
$ seq 1 5 | ./seds.pl -f commands.seds
1
3
4
```

Commands can be supplied separated by semicolons ; or newlines.

### Input Files

Input files can be specified on the command line:

```
$ seq 1 2 > two.txt
$ seq 1 5 > five.txt
$ ./seds.pl '4q;/2/d' two.txt five.txt
1
1
2
$ seq 1 2 > two.txt
$ seq 1 5 > five.txt
$ ./seds.pl '4q;/2/d' five.txt two.txt
1
3
4
$ echo 4q   >  commands.seds
$ echo /2/d >> commands.seds
$ seq 1 2 > two.txt
$ seq 1 5 > five.txt
$ ./seds.pl -f commands.seds two.txt five.txt
1
1
2
```

### Comments & White Space

Whitespace can appear before and/or after commands and addresses.

'#' can be used as a comment character, for example:

```
$ seq 24 43 | ./seds.pl ' 3, 17  d  # comment'
24
25
41
42
43
```

On both the command line and in a command file, a newline ends a comment.

```
$ seq 24 43 | ./seds.pl '/2/d # delete  ;  4  q # quit'
30
31
33
34
35
36
37
38
39
40
41
43
```

### -i command line option
The `Seds -i` command line options replaces file contents with the output of the Seds commands.

```
$ seq 1 5 >five.txt
$ cat five.txt
1
2
3
4
5
$ ./seds.pl -i /[24]/d five.txt
$ cat five.txt
1
3
5
```

### : - label command
The `Seds :` command indicates where b and t commands should continue execution.
There can not be an address before a label command.

### b - branch command
The `Seds b` command branches to the specified label, if the label is omitted, it branches to end of the script.

### t - conditional branch command

The `Seds t` command behaves the same as the b command except it branches only if there has been a successful substitute command since the last input line was read and since the last t command.

```
$ echo 1000001|./seds.pl ': start; s/00/0/; t start'
101
$ echo 0123456789|./seds.pl -n 'p; : begin;s/[^ ](.)/ \1/; t skip; q; : skip; p; b begin'
0123456789
 123456789
  23456789
   3456789
    456789
     56789
      6789
       789
        89
         9
```

### a - append command

The `Seds a` command appends the specified text.

```
$ seq 5 9 | ./seds.pl '3a hello'
5
6
7
hello
8
9
```

### i - insert command

The `Seds i` command inserts the specified text.

```
$ seq 5 9 | ./seds.pl '3i hello'
5
6
hello
7
8
9
```

### c - change command

The `Seds c` command replaces the selected lines with the specified text.

```
$ seq 5 9 | ./seds.pl '3c hello'
5
6
hello
8
9
```

### Other Sed Features
There are many sed features and commands other than those described above.

For example, sed provides extra commands including {} D h H g G l n p T w W x y which are not part of Seds.

For example, sed adds extra syntax to addresses including feature involving the characters: ! + ~ 0 \. These are not part of Seds.

For example, sed has a number of command-line options other than -i, -n and -f. These are not part of Seds.

<!-- LICENSE -->
## License

Distributed under the MIT License. See [`LICENSE`](/LICENSE) for more information.

<!-- CONTACT -->
## Contact

Zhuolin Li - lzlscx@gmail.com

Project Link: [https://github.com/ZL-Li/Seds](https://github.com/ZL-Li/Seds)