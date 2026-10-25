![](_page_0_Picture_0.jpeg)

![](_page_0_Picture_1.jpeg)

# **2.1 Experiencing the Power Play ...**

# **An Impossible Venture!**

Take a sheet of paper, as large a sheet as you can find. Fold it once. Fold it again, and again.

How many times can you fold it over and over?

Estu says "I heard that a sheet of paper can't be folded more than 7 times".

Roxie replies "What if we use a thinner paper, like a newspaper or a tissue paper?"

Try it with different types of paper and see what happens.

![](_page_0_Picture_10.jpeg)

Say you can fold a sheet of paper as many times as you wish. What would its thickness be after 30 folds? Make a guess.

Let us find out how thick a sheet of paper will be after 46 folds. Assume that the thickness of the sheet is 0.001 cm.

The following table lists the thickness after each fold. Observe that the thickness doubles after each fold.

| Fold | Thickness | Fold | Thickness | Fold | Thickness |
|------|-----------|------|-----------|------|-----------|
| 1    | 0.002 cm  | 7    | 0.128 cm  | 13   | 8.192 cm  |
| 2    | 0.004 cm  | 8    | 0.256 cm  | 14   | 16.384 cm |
| 3    | 0.008 cm  | 9    | 0.512 cm  | 15   | 32.768 cm |
| 4    | 0.016 cm  | 10   | 1.024 cm  | 16   | 65.536 cm |
| 5    | 0.032 cm  | 11   | 2.048 cm  | 17   | ≈ 131 cm  |
| 6    | 0.064 cm  | 12   | 4.096 cm  |      |           |

(We use the sign '≈' to indicate 'approximately equal to'.) After 10 folds, the thickness is just above 1 cm (1.024 cm). After 17 folds, the thickness is about 131 cm (a little more than 4 feet).

> Math Talk

Now, what do you think the thickness would be after 30 folds? 45 folds? Make a guess.

Fill the table below.

| Fold | Thickness | Fold | Thickness | Fold | Thickness |
|------|-----------|------|-----------|------|-----------|
| 18   | ≈ 262 cm  | 21   |           | 24   |           |
| 19   | ≈ 524 cm  | 22   |           | 25   |           |
| 20   | ≈ 10.4 m  | 23   |           | 26   |           |

After 26 folds, the thickness is approximately 670 m. Burj Khalifa in Dubai, the tallest building in the world, is 830 m tall.

| Fold | Thickness | Fold | Thickness |
|------|-----------|------|-----------|
| 27   | ≈ 1.3 km  | 29   |           |
| 28   |           | 30   |           |

After 30 folds, the thickness of the paper is about 10.7 km, the typical height at which planes fly. The deepest point discovered in the oceans is the Mariana Trench, with a depth of 11 km.

| Fold<br>Thickness | Fold<br>Thickness | Fold<br>Thickness |
|-------------------|-------------------|-------------------|
| 31                | 36                | 41                |
| 32                | 37                | 42                |
| 33                | 38                | 43                |
| 34                | 39                | 44                |
| 35                | 40                | 45                |

It might be hard to digest the fact that after just 46 folds, the thickness is more than 7,00,000 km. This is the power of **multiplicative growth,** also called **exponential growth.** Let us analyse the growth. We have seen that the thickness doubles after every fold.

| Fold 4 | 0.016 cm | Fold 9  | 0.512 cm |
|--------|----------|---------|----------|
| Fold 5 | 0.032 cm | Fold 10 | 1.024 cm |

Notice the change in thickness after two folds. By how much does it increase?

| Fold 4 | 0.016 cm |
|--------|----------|
| Fold 6 | 0.064 cm |
|        |          |

After any 3 folds, the thickness increases 8 times (= 2 × 2 × 2). Check if that is true. Similarly,

from any point, the thickness after 10 folds increases by 1024 times (= 2 multiplied by itself 10 times), as shown in the table below.

| Fold     | Thickness                            | Times increased by             |
|----------|--------------------------------------|--------------------------------|
| 0 to 10  | 1.024 cm – 0.001 cm<br>= 1.023 cm    | 1.024 ÷ 0.001<br>= 1024        |
| 10 to 20 | 10.485 m – 1.024 cm<br>≈ 10.474 m    | 10.485 m ÷ 1.024 cm<br>= 1024  |
| 20 to 30 | 10.737 km – 10.485 m<br>≈ 10.726 km  | 10.737 km ÷ 10.485 m<br>= 1024 |
| 30 to 40 | 10995 km – 10.737 km<br>≈ 10984.2 km | 10995 km ÷<br>10.737 km = 1024 |
|          |                                      |                                |

# **2.2 Exponential Notation and Operations**

The initial thickness of the paper was 0.001 cm.

Upon folding once, its thickness became 0.001 cm × 2 = 0.002 cm. Folding it twice, its thickness became —

0.001 cm × 2 × 2 = 0.004 cm, or 0.001 cm × 22 = 0.004 cm (in shorthand). Upon folding it thrice, its thickness became —

0.001 cm × 2 × 2 × 2, or 0.001 cm × 23 = 0.008 cm.

When folded four times, its thickness became —

0.001 cm × 2 × 2 × 2 × 2, or 0.001 cm × 24 = 0.016 cm.

Similarly, the expression for the thickness of the paper when folded 7 times will be 0.001 cm × 2 × 2 × 2 × 2 × 2 × 2 × 2, or 0.001 cm × 2<sup>7</sup> = 0.128 cm.

We have seen that square numbers can be expressed as *n*<sup>2</sup> and cube numbers as *n*<sup>3</sup> .

*n* × *n* = *n*<sup>2</sup> (read as '*n* squared' or '*n* raised to the power 2')

*n* × *n* × *n* = *n*<sup>3</sup> (read as '*n* cubed' or '*n* raised to the power 3') *n* × *n* × *n* × *n* = *n*<sup>4</sup> (read as '*n* raised to the power 4' or 'the 4th power of *n*') *n* × *n* × *n* × *n* × *n* × *n* × *n* = *n*<sup>7</sup> (read as '*n* raised to the power 7' or 'the 7th power of *n*') and so on.

In general, we write *na* to denote *n* multiplied by itself *a* times.

54 = 5 × 5 × 5 × 5 = 625.

54 is the exponential form of 625. Here, 4 is the **exponent/power,** and 5 is the **base.** Exponents of the form 5*<sup>n</sup>* are called powers of 5: 51 , 52 , 53 , 54 , etc. 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 = 210 = 1024. Remember the 1024 from earlier? There, it meant that after every 10 folds, the thickness increased 1024 times.

54 is read as '5 raised to the power 4' or '5 to the power 4' or '5 power 4' or '4th power of 5'

> > 1

Which expression describes the thickness of a sheet of paper after it is folded 10 times? The initial thickness is represented by the letter-number *v*.

| (i)<br>10v  | (ii) 10 + v | (iii) 2 × 10 × v |
|-------------|-------------|------------------|
| 210<br>(iv) | (v) 210v    | (vi) 102<br>v    |

Some more examples of exponential notation:

4 × 4 × 4 = 43 = 64.

(– 4) × (– 4) × (– 4) = (– 4)3 = – 64. Similarly,

*a* × *a* × *a* × *b* × *b* can be expressed as *a*<sup>3</sup> *b*2 (read as *a* cubed *b* squared). *a* × *a* × *b* × *b* × *b* × *b* can be expressed as *a*<sup>2</sup> *b*4 (read as *a* squared *b* raised to the power 4).

Remember that 4 + 4 + 4 = 3 × 4 = 12, whereas 4 × 4 × 4 = 43 = 64.

Express the number 32400 as a product of its prime factors and represent the prime factors in their exponential form. 2 32400 2 16200

32400 = 2 × 2 × 2 × 2 × 5 × 5 × 3 × 3 × 3 × 3.

In exponential form, this would be

32400 = 24 × 52 × 34 .

What is (– 1)5 ? Is it positive or negative? What about (– 1)56?

Is (– 2)4 = 16? Verify.

**Figure it Out**

What is 02 , 05 ? What is 0<sup>n</sup> ?

1. Express the following in exponential form:

- (i) 6 × 6 × 6 × 6 (ii) *y* × *y*

- (iii) *b* × *b* × *b* × *b* (iv) 5 × 5 × 7 × 7 × 7
- (v) *2 × 2 × a × a* (vi) *a × a × a × c × c × c × c × d*

*Power Play*

2. Express each of the following as a product of powers of their prime factors in exponential form.

(i) 648 (ii) 405 (iii) 540 (iv) 3600

3. Write the numerical value of each of the following:

| (i)  | 2 × 103            | (ii) | 72 |
|------|--------------------|------|----|
| (iv) | (– 3)2<br>× (– 5)2 | (v)  | 32 |

 × 23 (iii) 3 × 44 × 104 (vi) (– 2)5 × (– 10)6

# **The Stones that Shine ...**

Three daughters with curious eyes, Each got three baskets—a kingly prize. Each basket had three silver keys, Each opens three big rooms with ease. Each room had tables—one, two, three, With three bright necklaces on each, you see. Each necklace had three diamonds so fine… Can you count these stones that shine?

How many rooms were there altogether?

**Hint:** Find out the number of baskets and rooms.

![](_page_4_Picture_8.jpeg)

![](_page_4_Picture_9.jpeg)

From the diagram, the number of rooms is 34 . This can be computed by repeatedly multiplying 3 by itself,

```
3 × 3 = 9.
 9 × 3 = 27.
27 × 3 = 81.
81 × 3 = 243.
```

How many diamonds were there in total? Can we find out by just one multiplication using the products above?

The number of diamonds is 3 × 3 × 3 × 3 × 3 × 3 × 3 = 3<sup>7</sup> .

We can write

37 = (3 × 3 × 3 × 3) × (3 × 3 × 3)

We had computed till 34 . To find 3<sup>7</sup> , we can just multiply 34 (= 81) with 33 (= 27).

$$= 34 \times 33$$
  
= 81 \times 27 = 2187 
$$\underbrace{3 \times 3 \times 3 \times 3}_{34} \times \underbrace{3 \times 3 \times 3}_{33}$$

37 can also be written as 32 × 35 . Can you reason out why?

This can be easily extended to products where exponents are the same letter-numbers.

Write the product *p*<sup>4</sup> × *p*<sup>6</sup> in exponential form.

$$p^4 \times p^6 = (p \times p \times p \times p) \times (p \times p \times p \times p \times p \times p) = p^{10}.$$

We can generalise this to —

*n<sup>a</sup>*× *nb* = *na*<sup>+</sup>*<sup>b</sup>* , where *a* and *b* are counting numbers.

Use this observation to compute the following. (i) 29 (ii) 5<sup>7</sup> (iii) 46

Math Talk

46 can be evaluated in these two ways,

(4 × 4 × 4) × (4 × 4 × 4) = 43 × 43 = 64 × 64 = 4096. 43 × 43 is the square of 43 , i.e., 43 × 43 can also be written as (43 ) 2 . (4 × 4) × (4 × 4) × (4 × 4) = 42 × 42 × 42 = 16 × 16 × 16 = 4096. 42 × 42 × 42 is the cube of 42 , i.e., 42 × 42 × 42 can also be written as (42 ) 3 .

```
Similarly, 74
                  = (7 × 7) × (7 × 7) = 72
                                            × 72
                                                 = (72
                                                      )
                                                       2
                                                        , and
210 = (2 × 2) × (2 × 2) × (2 × 2) × (2 × 2) × (2 × 2) 
 = (22
         ) × (22
                ) × (22
                       ) × (22
                              ) × (22
                                     ) 
 = (22
         )
          5
           .
Is 210 also equal to (25
                          )
                           2
                            ? Write it as a product.
2
 10 = (2 × 2 × 2 × 2 × 2) × (2 × 2 × 2 × 2 × 2)
 = (25
          ) × (25
                 )
 = (25
          )
           2
           .
   In general,
        (na
           )
            b
              =(nb
                  )
                   a
                    = na × b
                           =n
                              ab, where a and b are counting numbers.
```

Write the following expressions as a power of a power in at least two different ways:

> (i) 86 (ii) 715 (iii) 914 (iv) 58

*Power Play*

## **Magical Pond**

In the middle of a beautiful, magical pond lies a bright pink lotus. The number of lotuses doubles every day in this pond. After 30 days, the pond is completely covered with lotuses. On which day was the pond half full?

If the pond is completely covered by lotuses on the 30th day, how much of it is covered by lotuses on the 29th day?

![](_page_6_Picture_4.jpeg)

Since the number of lotuses doubles every day, the pond should be half covered on the 29th day.

Write the number of lotuses (in exponential form) when the pond was —

- (i) fully covered (ii) half covered
- There is another pond in which the number of lotuses triples every day. When both the ponds had no flowers, Damayanti placed a lotus in the doubling pond. After 4 days, she took all the lotuses from there and put them in the tripling pond. How many lotuses will be in the tripling pond after 4 more days?

After the first 4 days, the number of lotuses is 1 × 2 × 2 × 2 × 2 = 24 . After the next 4 days, the number of lotuses is 24 × 3 × 3 × 3 × 3 = 24 × 34 .

What if Damayanti had changed the order in which she placed the flowers in the lakes? How many lotuses would be there?

$$1 \times 3^4 \times 2^4 = (3 \times 3 \times 3 \times 3) \times (2 \times 2 \times 2 \times 2).$$

Can this product be expressed as an exponent *mn* , where *m* and *n* are some counting numbers?

By regrouping the numbers,

= 
$$(3 \times 2) \times (3 \times 2) \times (3 \times 2) \times (3 \times 2)$$
  
=  $(3 \times 2)^4 = 6^4$ .

In general form,

*ma* × *na* = (*mn*) *a* , where *a* is a counting number.

Use this observation to compute the value of 25 × 55 .

Simplify <sup>104</sup> <sup>54</sup> and write it in exponential form.

In general, we can show that *ma na* = ( *m n* ) *a .*

## **How Many Combinations**

![](_page_7_Picture_2.jpeg)

Estu has 4 dresses and 3 caps. How many different ways can Estu combine the dresses and caps?

For each cap, he can choose any of the 4 dresses, so for 3 caps, 4 + 4 + 4 = 4 × 3 = 12 combinations are possible. We can also look at it as—for each dress, Estu can choose any of the 3 caps, so for 4 outfits, 3 + 3 + 3 + 3 = 3 × 4 = 12 combinations are possible.

![](_page_7_Picture_5.jpeg)

Roxie has 7 dresses, 2 hats, and 3 pairs of shoes. How many different ways can Roxie dress up?

**Hint:** Try drawing a diagram like the one above.

Estu and Roxie came across a safe containing old stamps and coins that their great-grandfather had collected. It was secured with a 5-digit password. Since nobody knew the password, they had no option except to try every password until it opened. They were unlucky and the lock only opened with the last password, after they had tried all possible combinations. How many passwords did they end up checking?

![](_page_7_Picture_9.jpeg)

![](_page_7_Picture_10.jpeg)

If you can't solve a problem, try to find a simpler version of the problem that you can solve. This technique can come in handy many times.

Instead of a 5-digit lock, let us assume we have a 2-digit lock and try to find out how many passwords are possible.

There are 10 options for the first digit (0 to 9). For each of these, there are 10 options for the second digit (If 0 is the first digit then 00, 01, 02, 03, …, 09 are possible). Therefore the total number of combinations for a 2-digit lock is 10 × 10 = 100.

Now, suppose we have a 3-digit lock. For each of the earlier 100 (2-digit) passwords there are 10 choices for the third digit. So, there are 100 × 10 = 1000 combinations for a 3-digit lock. You can list them all: 000, 001, 002, ….., 997, 997, 999.

![](_page_8_Picture_0.jpeg)

0

1

2

3

4

5

6

7

8

9

Try This

0

1

2

3

4

5

6

7

8

9

![](_page_8_Figure_1.jpeg)

Each digit has 10 choices, so a 5-digit lock will have:

10 × 10 × 10 × 10 × 10 = 105 = 1,00,000 passwords. This is the same as writing numbers till 99,999 with all 5 digits, i.e., 00000, 00001, 00002, …00010, 00011, …, 00100, 00101, …, 00999, …, 30456, …, 99998, 99999.

Estu says, "Next time, I will buy a lock that has 6 slots with the letters A to Z. I feel it is safer."

How many passwords are possible with such a lock?

- Think about how many combinations are possible in different contexts. Some examples are—
  - (i) Pincodes of places in India—The Pincode of Vidisha in Madhya Pradesh is 464001. The Pincode of Zemabawk in Mizoram is 796017.
  - (ii) Mobile numbers.

Oh no! Maybe my entire vacation will be gone trying to unlock this…

(iii) Vehicle registration numbers.

Try to find out how these numbers or codes are allotted/generated.

# **2.3 The Other Side of Powers**

Imagine a line of length 16 units. Erasing half of it would result in

24 ÷ 2 = 2 × 2 × 2 × 2 2 = 2 × 2 × 2 = 23 = 8 units.

Erasing half one more time would result in,

$$(2^4 \div 2) \div 2 = 2^4 \div 2^2 = \frac{2 \times 2 \times 2 \times 2}{2 \times 2} = 2 \times 2 = 2^2 = 4$$
 units.

Halving 16 cm three times may be written as,

24 ÷ 23 = 2 × 2 × 2 × 2 2 × 2 × 2 = 2 = 21 = 2 units.

From this we can see that

$$2^4 \div 2^3 = 2^{4-3} = 2^1$$
.

What is 2100 ÷ 225 in powers of 2?

In a generalised form,

$$n^a \div n^b = n^{a-b},$$

where *n* ≠ 0 and *a* and *b* are counting numbers and *a* > *b*.

![](_page_9_Picture_1.jpeg)

![](_page_9_Picture_2.jpeg)

We have not covered the case when the exponent is 0; for example, what is 20 ?

Let us define 20 in a way that the generalised form above holds true.

$$2^{0} = 2^{4-4} = 2^{4} \div 2^{4} = \frac{2 \times 2 \times 2 \times 2}{2 \times 2 \times 2 \times 2} = 1.$$

In fact for any letter number *a*

$$2^0 = 2^{a-a} = 2^a \div 2^a = 1.$$

In general,

$$x^a \div x^a = x^{a-a} = x^0$$
, and so  
 $1 = x^0$ ,

where *x* ≠ 0 and *a* is a counting number.

## **When Zero is in Power!**

![](_page_9_Picture_12.jpeg)

When a line of length 24 units is halved 5 times,

> 24 ÷ 25 = 2 × 2 × 2 × 2 2 × 2 × 2 × 2 × 2 = 1 <sup>2</sup> units.

Using the generalised form, we get 24 ÷ 25 = 2(4 – 5) = 2– 1. So, 2– 1 = 1 <sup>2</sup> . When a line of length 24 units is halved 10 times, we get 24 ÷ 210= 2(4 – 10) = 2– 6 units.

When expanded, 24 ÷ 210 = 2 × 2 × 2 × 2 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 × 2 = 1 <sup>26</sup> = 1 <sup>64</sup>, which is also written as 2– 6.

Similarly,  $10^{-3} = \frac{1}{10^{3}}$ ,  $7^{-2} = \frac{1}{7^{2}}$ , etc. ? Can we write  $10^3 = \frac{1}{10^{-3}}$ ? We can write,  $\frac{1}{10^{-3}} = \frac{1}{1/10^{3}} = 1 \div \frac{1}{10^{3}} = 1 \times 10^{3} = 10^{3}.$ Similarly,  $7^2 = \frac{1}{7^{-2}}$  and  $4^a = \frac{1}{4^{-a}}$ . In a generalised form, Math  $n^{-a} = \frac{1}{n^a}$  and  $n^a = \frac{1}{n^{-a}}$ , where  $n \neq 0$ . Talk Consider the following general forms we have identified.  $n^a \div n^b = n^{a-b}$  $n^a \times n^b = n^{a+b}$  $(n^a)^b = (n^b)^a = n^{a \times b}$ **?** We had required  $a$  and  $b$  to be counting numbers. Can  $a$  and  $b$  be any integers? Will the generalised forms still hold true? Write equivalent forms of the following. (i)  $2^{-4}$ (ii) 10<sup>-5</sup> (iii)  $(-7)^{-2}$ (v) 10<sup>-100</sup> (iv)  $(-5)^{-3}$ Simplify and write the answers in exponential form. (ii)  $3^2 \times 3^{-5} \times 3^6$ (iii)  $p^3 \times p^{-10}$ (i)  $2^{-4} \times 2^7$ (iv)  $2^4 \times (-4)^{-2}$ (v)  $8^p \times 8^q$ **Power Lines** Let us arrange the powers of 4 along a line.

![](_page_10_Figure_2.jpeg)

- Can we say that  $16384 \ (4^7)$  is  $16 \ (4^2)$  times larger than 1,024  $(4^5)$ ? Yes, since  $4^7 \div 4^5 = 4^2$ .
- How many times larger than  $4^{-2}$  is  $4^{2}$ ?
  - Use the power line for 7 to answer the following questions.

| $7^{7}$  | 823543          | $2,401 \times 49 =$                  |
|----------|-----------------|--------------------------------------|
| $7^{6}$  | 117649          | $49^3 =$                             |
| $7^{5}$  | 16807           |                                      |
| $7^4$    | 2401            | $343 \times 2{,}401 =$               |
| $7^{3}$  | 343             | $\frac{16,807}{49} =$                |
| $7^{2}$  | 49              |                                      |
| $7^{1}$  | 7               | $\frac{7}{343}$ =                    |
| $7^{0}$  | 1               | $\frac{16,807}{8,23,543} =$          |
| $7^{-1}$ | $\frac{1}{7}$   | $1,17,649 \times \frac{1}{343}$      |
| $7^{-2}$ | $\frac{1}{49}$  |                                      |
| $7^{-3}$ | $\frac{1}{343}$ | $\frac{1}{343} \times \frac{1}{343}$ |
| $7^{-4}$ | 2401            |                                      |

# 2.4 Powers of 10

We have used numbers like 10, 100, 1000, and so on when writing Indian numerals in an expanded form. For example,

 $47561 = (4 \times 10000) + (7 \times 1000) + (5 \times 100) + (6 \times 10) + 1.$ 

This can be written using powers of 10 as

 $(4 \times 10^4) + (7 \times 10^3) + (5 \times 10^2) + (6 \times 10^1) + (1 \times 10^0).$ 

Write these numbers in the same way: (i) 172, (ii) 5642, (iii) 6374.

How can we write 561.903?

 $561.903 = (5 \times 100) + (6 \times 10) + 1 + (9 \times \frac{1}{10}) + (0 \times \frac{1}{100}) + (3 \times \frac{1}{1000}).$ Writing it using powers of 10, we have

 $561.903 = (5 \times 10^{2}) + (6 \times 10^{1}) + (1 \times 10^{0}) + (9 \times 10^{-1}) + (0 \times 10^{-2}) + (3 \times 10^{-3}).$ 

## **Scientific Notation**

Let's look at some facts involving large numbers—

- (i) The Sun is located 30,00,00,00,00,00,00,00,00,000 m from the centre of our Milky Way galaxy.
- (ii) The number of stars in our galaxy is 1,00,00,00,00,000.
- (iii) The mass of the Earth is 59,76,00,00,00,00,00,00,00,00,00,000 kg.

As the number of digits increases, it becomes difficult to read the numbers correctly. We may miscount the number of zeroes or place commas incorrectly. We will then read the wrong value. It is like getting ₹5,000 when you were supposed to get ₹50,000. The number of zeroes is more important than the initial digits in several cases.

Can we use the exponential notation to simplify and read these very large numbers correctly?

For example, the number 5900 can be expressed as—

5900 = 590 × 10 = 590 × 101 = 59 × 100 = 59 × 102 = 5.9 × 1000 = 5.9 × 103 = 0.59 × 10000 = 0.59 × 104

.

Any number can be written as the product of a number between 1 and 10 and a power of 10. For example,

5900 = 5.9 × 103 20800 = 2.08 × 104 80,00,000 = 8 × 106

Write the large-number facts we read just before in this form.

In **scientific notation or scientific form** (also called **standard form)**, we write numbers as *x* × 10*<sup>y</sup>* , where *x* ≥ 1 and *x* < 10 is the coefficient and *y*, the exponent, is any integer. Often, the exponent *y* is more important than the coefficient *x*. When we write the 2 crore population of Mumbai as 2 × 10<sup>7</sup> , the 7 is more important than the 2. Indeed, if the 2 is changed to 3, the population increases by one-half, i.e., 2 crore to 3 crore, whereas if the 7 is changed to 8, the change in population is 10 times, i.e., 2 crores to 20 crores. Therefore, the standard form explicitly mentions the exponent, which indicates the number of digits.

If we say that the population of Kohima is 1,42,395, then it gives the impression that we are quite sure about this number up to the units place. When we use large numbers, in most cases, we are more concerned about how big a quantity or measure is, rather than the exact value. If we are only sure that the population is around 1 lakh 42 thousand, we can write it as 1.42 × 105 . If we can only be certain that it is around 1 lakh 40 thousand, we write it as 1.4 × 105 . The number of digits in the coefficient reflects how well we know the number. The most important part of any

number written in scientific form is the exponent, and then the first digit of the coefficient. The digits following the coefficient are small corrections to the first digit.

![](_page_13_Picture_2.jpeg)

These values are rounded-off estimates, averages, or approximations; most of the time, they serve the purpose at hand.

The distance between the Sun and Saturn is 14,33,50,00,00,000 m = 1.4335 × 1012 m.

The distance between Saturn and Uranus is 14,39,00,00,00,000 m = 1.439 × 1012 m. The distance between the Sun and Earth is 1,49,60,00,00,000 m = 1.496 × 1011 m.

Can you say which of the three distances is the smallest?

![](_page_13_Picture_7.jpeg)

The number line below shows the distance between the Sun and Saturn (1.4335 × 1012 m). On the number line below, mark the relative position of the Earth. The distance between the Sun and the Earth is 1.496 × 1011 m.

![](_page_13_Figure_9.jpeg)

# **2.5 Did You Ever Wonder?**

Last year, we looked at interesting thought experiments in the chapter on Large Numbers. Let us continue this journey.

Nanjundappa wants to donate jaggery equal to Roxie's weight and wheat equal to Estu's weight. He is wondering how much it would cost.

![](_page_14_Picture_4.jpeg)

What would be the worth (in rupees) of the donated jaggery? What would be the worth (in rupees) of the donated wheat?

In order to find out, let us first describe the relationships among the quantities present.

Worth of jaggery (in rupees) = Roxie's weight in kg × cost of 1 kg jaggery. Worth of wheat (in rupees) = Estu's weight in kg × cost of 1 kg wheat.

Make necessary and reasonable assumptions for the unknowns and find the answers. Remember, Roxie is 13 years old and Estu is 11 years old.

Assuming Roxie's weight to be 45 kg and the cost of 1 kg of jaggery to be ₹70, the worth of donated jaggery is 45 × 70 = ₹3150. Assuming Estu's weight to be 50 kg and the cost of 1 kg of wheat to be ₹50, the worth of donated wheat is 50 × 50 = ₹2500.

*The practice of offering goods equal to the weight of a person, called Tulābhāra or Tulābhāram, is quite old and is still followed in many places in Southern India. It is a symbol of bhakti (surrendering oneself), a token of gratitude; it also supports the community.*

Roxie wonders, "Instead of jaggery if we use 1-rupee coins, how many coins are needed to equal my weight?". How can we find out?

For questions like these, you can consider following the steps suggested below.

1. Guessing: Make an instinctive (quick) guess of what the answer could be, without any calculations.

- 2. Calculating using estimation and approximation
  - (i) Describe the relationships among the quantities that are needed to find the answer.
  - (ii) Make reasonable assumptions and approximations if the required information is not available.
  - (iii) Compute and find the answer (and check how close your guess was).
- Would the number of coins be in hundreds, thousands, lakhs, crores, or even more? Make an instinctive guess.
- Find the answer by making necessary and reasonable assumptions and approximations for the unknowns. Remember, we are not looking for an exact answer but a reasonably close estimate.

How about measuring to find out the weight of a 1-rupee coin?

![](_page_15_Picture_8.jpeg)

Initially, your guesses may be very far off from the answer and it is perfectly fine! You will get better at it like as you do it often and in different situations. Guessing and estimating can build intuition about numbers and various quantities.

Estu asks, "What if we use 5-rupee coins or 10-rupee notes instead? How much money could it be?"

Make an instinctive guess first. Then find out (make necessary and reasonable assumptions about the unknown details and find the answers).

Estu says, "When I become an adult, I would like to donate notebooks worth my weight every year". Roxie says, "When I grow up, I would like to do *annadāna* (offering grains or meals) worth my weight every year".

How many people might benefit from each of these offerings in a year? Again, guess first before finding out.

![](_page_15_Picture_14.jpeg)

Roxie and Estu overheard someone saying—"We did *pādayātra* for about 400 km to reach this place! We arrived early this morning."

- How long ago would they have started their journey?
- Find answers by making necessary assumptions and approximations. Do guess first before calculating to check how close your guess was!

**Note to the Teacher:** Assumptions can vary greatly at times, and as a result the answers computed using these you can also vary. This is perfectly alright. Modelling the situation properly is crucial, which can also be done in different ways sometimes. The accuracy of the assumed numbers or quantities can get better with exposure and practice.

*Pādayātra, is the traditional practice of walking long distances as part of a religious or spiritual pursuit. People across religions in our country observe similar forms of pilgrimage or spiritual walking, although they may have different names or purposes.*

*Some of the pilgrimages are Ajmer Sharif Dargah Ziyarat, Pandharpur Wari, Kānwar Yatra, Sabarimala Yatra, Sammed Shikharji Yatra, Lumbini to Sarnath Yatra.*

Before the rise of modern transport, people moved from one place to another by walking — sometimes merchants, sages, and scholars walked thousands of kilometres to different parts of the world across deserts, mountains, and rivers.

How many times can a person circumnavigate (go around the world) the Earth in their lifetime if they walk non-stop? Consider the distance around the Earth as 40,000 km.

# **Linear Growth vs. Exponential Growth**

Roxie tells Estu about a science-fiction novel she is reading where they

build a ladder to reach the moon, "... I wonder if we actually had a ladder like that, how many steps would it have?".

- What do you think? Make an instinctive guess first.
- Would the number of steps be in thousands, lakhs, crores, or even more?

To find out, we would

![](_page_16_Picture_11.jpeg)

need to know the gap between consecutive steps of the ladder. Let's assume a reasonable distance of 20 cm. Visualising the problem as shown,

![](_page_17_Figure_1.jpeg)

We have to find out how many 20 cm make 3,84,400 km.

If we calculate the value, we get the result as 1,92,20,00,000 steps, which is 192 crore and 20 lakh steps or 1 billion 922 million steps. The fixed increase in the distance from the earth with each step (a 20 cm gain after each step) is called **linear growth.** 

To cover the distance between the Earth and the Moon, it takes 1,92,20,00,000 steps with linear growth whereas it takes just 46 folds of a piece of paper with exponential growth! Linear growth is additive, whereas exponential growth is multiplicative.

![](_page_17_Figure_5.jpeg)

Some examples of exponential growth we have seen earlier in this chapter are 'The Stones that Shine', 'Magical Pond', 'How Many Combinations'. We shall explore more such interesting examples in a later chapter and also in the next grade.

Can you come up with some examples of linear growth and of exponential growth?

## **Getting a Sense for Large Numbers**

Last year, we learnt about lakhs and crores, as well as millions and billions. A lakh is 105 (1,00,000), a crore is 10<sup>7</sup> (1,00,00,000), and an arab is 109 (1,00,00,00,000), whereas a million is 106 (1,000,000) and a billion is 109 (1,000,000,000).

You might know the size of the world's human population. Have you ever wondered how many ants there might be in the world or how long ago humans emerged? In this section, we shall explore numbers significantly larger than arabs and billions. We shall use powers of 10 to represent and compare these numbers in each case.

100 As of mid-2025, there are only two northern white rhinos remaining in the world, both females, and they reside at the Ol Pejeta Conservancy in Kenya (= 2 × 100 ).

- 101 As of early 2024, the total population of Hainan gibbons is a meagre 42 ( ≈ 4 × 101 ).
- 102 There are just 242 Kakapo alive as of mid-2025 (≈ 2 × 102 ).
- 103 There are fewer than 3000 Komodo dragons in the world, all based in Indonesia (≈ 3 × 103 ).
- 104 A 2005 estimate of the maned wolf population showed that there are more than 17000 of them; most are located in Brazil (1.7 × 104 ).

![](_page_18_Picture_5.jpeg)

- 105 As of 2018, there are around 4.15 lakh African elephants (≈ 4 × 105 ).
- 106 There are an estimated 50 lakh / 5 million American alligators as of 2025 (5 × 106 ).
- 10<sup>7</sup> The global camel population is estimated to be over 3.5 crore/ 35 million (3.5 × 10<sup>7</sup> ). India has only about 2.5 lakhs of them. The global horse population is around 5.8 crore / 58 million (5.8 × 10<sup>7</sup> ), with about half of them in America.
- 108 More than 20 crore / 200 million (2 × 108 ) water buffaloes are estimated worldwide, with a vast majority of them in Asia.
- 109 The estimated global population of starlings is around 1.3 arab/1.3 billion (\_\_\_\_\_\_\_\_\_). The global human population as of 2025 is 8.2 arab/8.2 billion (8.2 × 109 ).

![](_page_18_Picture_11.jpeg)

A picture of a starling murmuration over a farm in the UK. Starling murmuration is a mesmerising aerial display of thousands of starlings flying in synchronised, swirling patterns. It is often described as a 'choreographed dance'.

With a global human population of about 8 × 109 and about 4 × 105 African elephants, can we say that there are nearly 20,000 people for every African elephant?

- 1010 The global chicken population living at any time is estimated at ≈ 33 billion (3.3 × 1010).
- 1012 The estimated number of trees (2023) globally stands at 30 kharab/3 trillion (3 × 1012). One kharab is 100 arab, and one trillion is 1000 billion.
- 1014 The estimated mosquito population worldwide (2023) is 11 neel/110 trillion (\_\_\_\_\_\_\_\_). A derived estimate of the population of the Antarctic krill stands at 50 neel/500 trillion (5 × 1014).
- 1015 An estimate of the beetle population stands at 1 padma/1 quadrillion (1 × 1015). The estimate of the earthworm population is also at 1 padma/1 quadrillion.
- 1016 The estimated population of ants globally is 20 padma/20 quadrillion (2 × 1016). Ants alone outweigh all wild birds and wild mammals combined.

1021 is supposed to be the number of grains of sand on all beaches and deserts on Earth. This is enough sand to give every ant 10 little sand castles to live in.

![](_page_19_Picture_8.jpeg)

![](_page_19_Picture_9.jpeg)

- 1023 The estimated number of stars in the observable universe is 2 × 1023.
- 1025 There are an estimated 2 × 1025 drops of water on Earth (assuming 16 drops per millilitre).

Calculate and write the answer using scientific notation:

- (i) How many ants are there for every human in the world?
- (ii) If a flock of starlings contains 10,000 birds, how many flocks could there be in the world?

- (iii) If each tree had about 104 leaves, find the total number of leaves on all the trees in the world.
- (iv) If you stacked sheets of paper on top of each other, how many would you need to reach the Moon?

**A different way to say your age!** "How old are you?" asked Estu. "I completed 13 years a few weeks ago!" said Roxie. "How old are you?" asked Estu again. "I'm 4840 days old today!" said Roxie. "How old are you?" asked Estu again. "I'm \_\_\_\_\_\_ hours old!" said Roxie. Make an estimate before finding this number.

Estu: "I am 4070 days old today. Can you find out my date of birth?"

![](_page_20_Picture_5.jpeg)

What could this number mean? Find out!

If you have lived for a million seconds, how old would you be?

We shall look at approximate times and timelines of some events and phenomena, and use powers of 10 to represent and compare these quantities.

| Time in seconds     |        | Comparison to real-world events/phenomena                                                                                                                            |
|---------------------|--------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 100 = 1 second      | -      | Time taken for a ball thrown up to fall back on the<br>ground (typically a few seconds).                                                                             |
| 101<br>= 10 seconds | -<br>- | Time blood takes to complete one full circulation<br>through the body: 10–20 seconds (1 × 101<br>– 2 × 101<br>seconds).<br>Typical waiting time at a traffic signal. |

![](_page_20_Picture_10.jpeg)

Isn't it quite amazing how someone is able to estimate things like the number of ants in the world or the time blood takes to fully circulate? You may carry this wonder whenever you encounter such facts. You will come across such facts in subjects like Science and Social Science, where such estimates are made frequently.

| 102<br>seconds<br>≈1.6 minutes | - | Time needed to make a cup of tea: 5–10 minutes<br>(≈ 4 × 102<br>– 8 × 102<br>seconds).     |
|--------------------------------|---|--------------------------------------------------------------------------------------------|
|                                | - | Time for light to reach the Earth from the Sun: about<br>8 minutes (≈ 5 × 102<br>seconds). |

minutes… They should approximate it as *order of 10<sup>2</sup> seconds noodles*  — that way whether it takes 120 seconds or 900 seconds, the claim will be true.

These liars!! It never gets cooked before 10

103 seconds ≈ 16.6 minutes - Satellites in low Earth orbits take between 90 minutes (≈ 5.5 × 103   seconds) to 2 hours to complete one full revolution around the Earth.

104 seconds ≈ 2.7 hours

- The time needed to digest a meal: about 2–4 hours to pass through the stomach.
- Lifespan of an adult mayfly: about a day (≈ 9 × 104 seconds).

105 seconds ≈ 1.16 days and 106 seconds ≈ 11.57 days. Think of some events or phenomena whose time is of the order of (i) 105 seconds and (ii) 106 seconds. Write them in scientific notation.

| 107<br>seconds<br>-                 | Time spent sleeping in a year: about 4 months.                                                                                                                                                               |
|-------------------------------------|--------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| ≈ 115.7 days /<br>-<br>≈ 3.8 months | Time taken by Mangalyaan mission to reach Mars:<br>298 days (≈ 2.65 × 107 seconds).                                                                                                                          |
| -                                   | Time taken by Mars for one full revolution around<br>the Sun: 687 Earth-days/1.88 Earth-years<br>(≈ 6 × 107<br>seconds).                                                                                     |
| 108<br>seconds<br>-<br>≈ 3.17 years | The typical lifespan of most dogs is 3 to 15 years.                                                                                                                                                          |
| 109<br>seconds<br>-<br>≈ 31.7 years | The orbital period of Halley's comet is 75–79 years;<br>the next expected return is in the year 2061<br>(≈ 2.4 × 109<br>seconds).                                                                            |
| -                                   | Duration of one full revolution of Neptune around<br>the Sun: 60,190 Earth-days/~165 Earth-years or<br>89,666 Neptunian days/1 Neptunian-year (≈ 5.2 × 109<br>seconds). A day on Neptune is about 16.1 hours |

Notice how rapid exponential growth is—106 seconds is less than a fortnight, but 109 seconds is a whopping 31 years (about half the life expectancy of a human)!

1010 seconds ≈ 317 years - The Chola dynasty ruled for more than 900 years (≈ 3 × 1010 seconds) between the 3rd Century BCE and 12th Century CE.

1011 seconds ≈ 3,170 years - Age of the oldest known living tree: about 5000 years (≈ 1.57 × 1011 seconds).

> - Time since the last peak ice age: 19,000 – 26,000 years ago (≈ 6 × 1011 seconds – 8.2 × 1011 seconds).

1012 seconds ≈ 31,700 years - Early Homo sapiens first appeared 2–3 lakh years ago (≈7 × 1012 – 9 × 1012 seconds). The entire population around that time could fit in a large cricket stadium.

1013 seconds ≈ 3.17 lakh years - The Steppe Mammoth is estimated to have appeared around 8–18 lakh years ago.

![](_page_22_Picture_7.jpeg)

1014 seconds ≈ 3.17 million years - A fossil of Kelenken Guillermoi, a type of terror bird, is dated to 15 million years ago ( ≈\_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ seconds).

![](_page_22_Picture_9.jpeg)

1015 seconds ≈ 3.17 crore years - Age of Himalayas: 5.5 crore years/55 million years (≈ 1.7 × 1015 seconds); they continue to grow a few mm every year.

- Dinosaurs went extinct 6.6 crore years ago/66 million years ago (≈ 2 × 1015 seconds).
- Dinosaurs first appeared more than 20 crore/200 million years ago (≈ 6 × 1015 seconds).

- It takes about 23 crore years for the Sun to make one complete trip around the Milky Way (≈ 7 × 1015 seconds).

1016 seconds ≈ 31.7 crore years - Plants on land started 47 crore/470 million years ago ( ≈ \_\_\_\_\_\_\_\_\_\_\_\_\_\_\_ seconds). 1017 seconds ≈ 3.17 billion years The oldest fossil evidence suggests that bacteria first appeared about 3.7 billion years ago.

- The Earth is 4.5 billion years old.
- The Milky Way galaxy was formed 13.6 billion years ago, and the Universe was formed 13.8 billion years ago.

Notice that 109 seconds is of the order of the lifespan of a human, whereas 1018 seconds ago the universe did not exist according to modern physics!! The exponential notation can capture very large quantities in a concise manner.

Calculate and write the answer using scientific notation:

- (i) If one star is counted every second, how long would it take to count all the stars in the universe? Answer in terms of the number of seconds using scientific notation.
- (ii) If one could drink a glass of water (200 ml) every 10 seconds, how long would it take to finish the entire volume of water on Earth?

![](_page_23_Picture_8.jpeg)

![](_page_23_Picture_9.jpeg)

Very large quantities are often beyond our experience and comprehension. To put them into perspective, we can relate and compare them with quantities we are familiar with. This can give an essence of how large a number or a measure is!

# **2.5 A Pinch of History**

In the *Lalitavistara*, a Buddhist treatise from the first century BCE, we see number -names for odd powers of ten up to 1053. The following occurs as part of the dialogue between the mathematician Arjuna and Prince Gautama, the *Bodhisattva*.

"Hundred *kotis* are called an *ayuta* (109 ), hundred *ayutas* a *niyuta* (1011), hundred *niyutas* a *kankara* (1013), …, hundred *sarva-balas* a *visamjnagati* (1047), hundred *visamjna-gatis* a *sarvajna* (1049), hundred *sarvajnas* a *vibhutangama* (1051), a hundred *vibhutangamas* is a *tallakshana* (1053)."

Mahaviracharya gives a list of 24 terms (i.e., up to 1023) in his treatise *Ganita-sara-sangraha*. An anonymous Jaina treatise *Amalasiddhi* gives a list with a name for each power of ten up to 1096 *(dasha-ananta)*. A Pali grammar treatise of *Kāccāyana* lists number-names up to 10140, named *asaṅkhyeya*.

For expressing high powers of ten, Jaina and Buddhist texts use bases like *sahassa* (thousand) and *koṭi* (ten million); for instance, *prayuta* (106 ) would be *dasa sata sahassa* (ten hundred thousand).

The modern naming is similar to this, where we say,

| A hundred<br>thousand is a lakh | 100 × 1000 = 1,00,000                       | 102<br>× 103<br>= 105  |
|---------------------------------|---------------------------------------------|------------------------|
| A hundred lakhs<br>is a crore   | 100 × 1,00,000 = 1,00,00,000                | 102<br>× 105<br>= 107  |
| A hundred crores<br>is an arab  | 100 × 1,00,00,000 = 1,00,00,00,000          | 102<br>× 107<br>= 109  |
| A hundred arab is<br>a kharab   | 100 × 1,00,00,00,000<br>= 1,00,00,00,00,000 | 102<br>× 109<br>= 1011 |

Continuing this, a hundred kharab is a neel (1013), a hundred *neel* is a padma (1015), a hundred *padma* is a *shankh* (1017) and a hundred *shankh* is a *maha shankh* (1019).

In the American/International system, we say

- A thousand thousand is a million 1000 × 1000 = 1,000,000 103 × 103 = 106
- A thousand million is a billion 1000 × 1,000,000 = 1,000,000,000 103 × 106 = 109
- A thousand billion is an trillion 1000 × 1,000,000,000 = 1,00,000,000,000 103 × 109 = 1012

Continuing this, a thousand trillion is a quadrillion (1015). This pattern continues. Observe the names **mi**llion (106 ), **bi**llion (109 ), **tr**illion (1012), **quad**rillion (1015), **quin**tillion (1018), **sext**illion (1021), **sept**illion (1024), **oct**illion (1027), **non**illion (1030), **dec**illion (1033).

What does the first part of each name denote?

The number 10100 is also called a googol. The estimated number of atoms in the universe is 1078 to 1082. The number 10googol is called a googolplex. It is hard to imagine how large this number is!

The currency note with the highest denomination in India currently is 2000 rupees. Guess what is the highest denomination of a currency note ever, across the world. The highest numerical value banknote ever printed was a special note valued 1 sextillion pengő (1021 or 1 milliard bilpengő) printed in Hungary in 1946, but it was never issued. In 2009, Zimbabwe printed a 100 trillion (1014) Zimbabwean dollar note, which at the time of printing was worth about \$30.

![](_page_25_Picture_1.jpeg)

![](_page_25_Picture_2.jpeg)

## **Figure it Out**

- 1. Find out the units digit in the value of 2224 ÷ 432? [Hint: 4 = 22 ]
- 2. There are 5 bottles in a container. Every day, a new container is brought in. How many bottles would be there after 40 days?
- 3. Write the given number as the product of two or more powers in three different ways. The powers can be any integers.
  - (i) 643 (ii) 1928 (iii) 32–5
- 4. Examine each statement below and find out if it is 'Always True', 'Only Sometimes True', or 'Never True'. Explain your reasoning.
  - (i) Cube numbers are also square numbers.
  - (ii) Fourth powers are also square numbers.
  - (iii) The fifth power of a number is divisible by the cube of that number.
  - (iv) The product of two cube numbers is a cube number.
  - (v) *q*46 is both a 4th power and a 6th power (*q* is a prime number).
- 5. Simplify and write these in the exponential form.

| (i)   | 10– 2 × 10– 5 | (ii) | 57<br>÷ 54     |
|-------|---------------|------|----------------|
| (iii) | 9– 7 ÷ 94     | (iv) | – 3<br>(13– 2) |

- (v) *m*<sup>5</sup> *n*<sup>12</sup>(*mn*) 9
- 6. If 122 = 144 what is
  - (i) (1.2)2 (ii) (0.12)2 (iii) (0.012)2 (iv) 1202

*Power Play*

7. Circle the numbers that are the same—

24 × 36 64 × 32 610 182 × 62 624

- 8. Identify the greater number in each of the following— (i) 43 or 34 (ii) 28 or 82 (iii) 1002 or 2100
- 9. A dairy plans to produce 8.5 billion packets of milk in a year. They want a unique ID (identifier) code for each packet. If they choose to use the digits 0–9, how many digits should the code consist of?
- 10. 64 is a square number (82 ) and a cube number (43 ). Are there other numbers that are both squares and cubes? Is there a way to describe such numbers in general?
- 11. A digital locker has an alphanumeric (it can have both digits and letters) passcode of length 5. Some example codes are G89P0, 38098, BRJKW, and 003AZ. How many such codes are possible?
- 12. The worldwide population of sheep (2024) is about 109 , and that of goats is also about the same. What is the total population of sheep and goats?
  - (ii) 209 (ii) 1011 (iii) 1010 (iv) 1018 (v) 2 × 109 (vi) 109 + 109
- 13. Calculate and write the answer in scientific notation:
  - (i) If each person in the world had 30 pieces of clothing, find the total number of pieces of clothing.
  - (ii) There are about 100 million bee colonies in the world. Find the number of honeybees if each colony has about 50,000 bees.
  - (iii) The human body has about 38 trillion bacterial cells. Find the bacterial population residing in all humans in the world.
  - (iv) Total time spent eating in a lifetime in seconds.
- 14. What was the date 1 arab/1 billion seconds ago?

![](_page_26_Picture_15.jpeg)

45

Math Talk

![](_page_27_Picture_1.jpeg)

- � We analysed some situations, asked questions, and found answers by first guessing, then modelling the problem statement, followed by making assumptions and approximations to carry out the calculations.
- We experienced how rapid exponential growth, also called multiplicative growth, can be compared to additive growth.
- *na* is *n* × *n* × *n* × *n* ×…× *n* (*n* multiplied by itself *a* times) and *n–a* = <sup>1</sup> *na*.
- Operations with exponents satisfy
  - y *na* × *nb* = *na*<sup>+</sup>*<sup>b</sup>*
  - y (*n<sup>a</sup>* ) *b* = (*nb* ) *<sup>a</sup>* = *na*<sup>×</sup>*<sup>b</sup>*
  - y *na* ÷ *nb* = *na <sup>b</sup> (n ǂ* 0)
  - y *na* × *ma* = (*n* × *m*) *a*
  - y *na* ÷ *ma* = (*n* ÷ *m*) *<sup>a</sup>(m ǂ* 0)
  - y *n*<sup>0</sup> = 1 *(n ǂ* 0)
- The scientific notation for the number 308100000 is 3.081 × 108 . The **standard form** of the **scientific notation** of any number is *x* × 10*<sup>y</sup>* , where *x* ≥ 1 and *x* < 10, and *y* is an integer.
- Engaging in interesting thought experiments can be used as means to understand how large a number or a quantity is.

![](_page_28_Picture_0.jpeg)

Find a partner to play this game with. In 10 seconds, the person who writes a number or an expression, using only the digits 0-9 and arithmetic operations, that gives a number that is the larger between the two wins the round.

In Round 1, Roxie wrote 10000000000000 and Estu wrote 999999 × 999999. Between these two, Roxie's number is greater. Can you see why? Roxie's number is 1013, whereas Estu's number is less than (106 ) 2 .

In Round 2, Roxie wrote 101000 + 101000 + 101000 + 101000 and Estu wrote (101000000) × 9000. Can you say which is greater?

Below are some conditions that you may consider for different rounds.

- (i) Exponents are not allowed. Only addition is allowed.
- (ii) Exponents are not allowed. Only addition and multiplication are allowed.
- (iii) Exponents are allowed. Only addition is allowed.

(iv) Exponents are allowed. Any arithmetic operation is allowed. You can create your own conditions and/or involve more people to play together.

![](_page_28_Picture_13.jpeg)