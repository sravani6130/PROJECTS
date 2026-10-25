# **INFINITE SERIES**

#### **A.1.1** Introduction

As discussed in the Chapter 9 on Sequences and Series, a sequence  $a_1, a_2, ..., a_n, ...$  having infinite number of terms is called *infinite sequence* and its indicated sum, i.e.,  $a_1 + a_2 + a_3 + ... + a_n + ...$  is called an *infinite series* associated with infinite sequence. This series can also be expressed in abbreviated form using the sigma notation, i.e.,

$$a_1 + a_2 + a_3 + \ldots + a_n + \ldots = \sum_{k=1}^{\infty} a_k$$

In this Chapter, we shall study about some special types of series which may be required in different problem situations.

## A.1.2 Binomial Theorem for any Index

In Chapter 8, we discussed the Binomial Theorem in which the index was a positive integer. In this Section, we state a more general form of the theorem in which the index is not necessarily a whole number. It gives us a particular type of infinite series, called *Binomial Series*. We illustrate few applications, by examples.

We know the formula

$$(1+x)^n = {}^nC_0 + {}^nC_1 x + \dots + {}^nC_n x^n$$

Here, n is non-negative integer. Observe that if we replace index n by negative integer or a fraction, then the combinations  ${}^{n}C_{r}$  do not make any sense.

We now state (without proof), the Binomial Theorem, giving an infinite series in which the index is negative or a fraction and not a whole number.

Theorem The formula

$$(1+x)^m = 1 + mx + \frac{m(m-1)}{1.2}x^2 + \frac{m(m-1)(m-2)}{1.2.3}x^3 + \dots$$

holds whenever |x| < 1.

**Remark** 1. Note carefully the condition |x| < 1, i.e., -1 < x < 1 is necessary when m is negative integer or a fraction. For example, if we take x = -2 and m = -2, we obtain

$$(1-2)^{-2} = 1 + (-2)(-2) + \frac{(-2)(-3)}{1.2}(-2)^2 + \dots$$

or

$$1 = 1 + 4 + 12 + \dots$$

This is not possible

2. Note that there are infinite number of terms in the expansion of  $(1+x)^m$ , when m is a negative integer or a fraction

Consider

$$(a+b)^{m} = \left[a\left(1+\frac{b}{a}\right)\right]^{m} = a^{m}\left(1+\frac{b}{a}\right)^{m}$$

$$= a^{m}\left[1+m\frac{b}{a}+\frac{m(m-1)}{1.2}\left(\frac{b}{a}\right)^{2}+\dots\right]$$

$$= a^{m}+ma^{m-1}b+\frac{m(m-1)}{1.2}a^{m-2}b^{2}+\dots$$

This expansion is valid when  $\left| \frac{b}{a} \right| < 1$  or equivalently when |b| < |a|.

The general term in the expansion of  $(a + b)^m$  is

$$\frac{m(m-1)(m-2)...(m-r+1)a^{m-r}b^r}{1.2.3..r}$$

We give below certain particular cases of Binomial Theorem, when we assume |x| < 1, these are left to students as exercises:

- 1.  $(1+x)^{-1} = 1 x + x^2 x^3 + \dots$
- 2.  $(1-x)^{-1} = 1 + x + x^2 + x^3 + \dots$
- 3.  $(1+x)^{-2} = 1 2x + 3x^2 4x^3 + \dots$
- 4.  $(1 x)^{-2} = 1 + 2x + 3x^2 + 4x^3 + \dots$

**Example 1** Expand  $\left(1-\frac{x}{2}\right)^{-\frac{1}{2}}$ , when |x| < 2.

**Solution** We have

$$\left(1 - \frac{x}{2}\right)^{-\frac{1}{2}} = 1 + \frac{\left(-\frac{1}{2}\right)\left(-\frac{x}{2}\right) + \frac{\left(-\frac{1}{2}\right)\left(-\frac{3}{2}\right)}{1.2}\left(-\frac{x}{2}\right)^2 + \dots$$
$$= 1 + \frac{x}{4} + \frac{3x^2}{32} + \dots$$

#### **A.1.3** Infinite Geometric Series

From Chapter 9, Section 9.5, a sequence  $a_1$ ,  $a_2$ ,  $a_3$ , ...,  $a_n$  is called G.P., if  $\frac{a_{k+1}}{a_k} = r$  (constant) for k = 1, 2, 3, ..., n-1. Particularly, if we take  $a_1 = a$ , then the resulting sequence  $a, ar, ar^2, ..., ar^{n-1}$  is taken as the standard form of G.P., where a is first term and r, the common ratio of G.P.

Earlier, we have discussed the formula to find the sum of finite series  $a + ar + ar^2 + ... + ar^{n-1}$  which is given by

$$S_n = \frac{a\left(1 - r^n\right)}{1 - r} \, .$$

In this section, we state the formula to find the sum of infinite geometric series  $a + ar + ar^2 + ... + ar^{n-1} + ...$  and illustrate the same by examples.

Let us consider the G.P. 1,  $\frac{2}{3}$ ,  $\frac{4}{9}$ ,...

Here a = 1,  $r = \frac{2}{3}$ . We have

$$S_n = \frac{1 - \left(\frac{2}{3}\right)^n}{1 - \frac{2}{3}} = 3\left[1 - \left(\frac{2}{3}\right)^n\right] \qquad \dots (1)$$

Let us study the behaviour of  $\left(\frac{2}{3}\right)^n$  as *n* becomes larger and larger.

| n                            | 1      | 5            | 10            | 20            |
|------------------------------|--------|--------------|---------------|---------------|
| $\left(\frac{2}{3}\right)^n$ | 0.6667 | 0.1316872428 | 0.01734152992 | 0.00030072866 |

We observe that as *n* becomes larger and larger,  $\left(\frac{2}{3}\right)^n$  becomes closer and closer to

zero. Mathematically, we say that as *n* becomes sufficiently large,  $\left(\frac{2}{3}\right)^n$  becomes

sufficiently small. In other words, as  $n \to \infty$ ,  $\left(\frac{2}{3}\right)^n \to 0$ . Consequently, we find that the sum of infinitely many terms is given by S = 3.

Thus, for infinite geometric progression  $a, ar, ar^2, ...,$  if numerical value of common ratio r is less than 1, then

$$S_n = \frac{a(1-r^n)}{1-r} = \frac{a}{1-r} - \frac{ar^n}{1-r}$$

In this case,  $r^n \to 0$  as  $n \to \infty$  since |r| < 1 and then  $\frac{ar^n}{1-r} \to 0$ . Therefore,  $S_n \to \frac{a}{1-r}$  as  $n \to \infty$ .

$$S_n \to \frac{a}{1-r}$$
 as  $n \to \infty$ 

Symbolically, sum to infinity of infinite geometric series is denoted by S. Thus,

 $S = \frac{a}{1 - \kappa}$ we have

For example

(i) 
$$1 + \frac{1}{2} + \frac{1}{2^2} + \frac{1}{2^3} + \dots = \frac{1}{1 - \frac{1}{2}} = 2$$

(ii) 
$$1 - \frac{1}{2} + \frac{1}{2^2} - \frac{1}{2^3} + \dots = \frac{1}{1 - \left(-\frac{1}{2}\right)} = \frac{1}{1 + \frac{1}{2}} = \frac{2}{3}$$

**Example 2** Find the sum to infinity of the G.P.;

$$\frac{-5}{4}$$
,  $\frac{5}{16}$ ,  $\frac{-5}{64}$ ,....

Solution Here  $a = \frac{-5}{4}$  and  $r = -\frac{1}{4}$ . Also |r| < 1.

Hence, the sum to infinity is  $\frac{-\frac{5}{4}}{1+\frac{1}{4}} = \frac{-\frac{5}{4}}{\frac{5}{4}} = -1.$ 

### **A.1.4** Exponential Series

Leonhard Euler (1707 – 1783), the great Swiss mathematician introduced the number e in his calculus text in 1748. The number e is useful in calculus as  $\pi$  in the study of the circle.

Consider the following infinite series of numbers

$$1 + \frac{1}{1!} + \frac{1}{2!} + \frac{1}{3!} + \frac{1}{4!} + \dots$$
 ... (1)

The sum of the series given in (1) is denoted by the number e

Let us estimate the value of the number *e*.

Since every term of the series (1) is positive, it is clear that its sum is also positive. Consider the two sums

$$\frac{1}{3!} + \frac{1}{4!} + \frac{1}{5!} + \dots + \frac{1}{n!} + \dots$$
 ... (2)

and

$$\frac{1}{2^2} + \frac{1}{2^3} + \frac{1}{2^4} + \dots + \frac{1}{2^{n-1}} + \dots$$
 ... (3)

Observe that

$$\frac{1}{3!} = \frac{1}{6} \text{ and } \frac{1}{2^2} = \frac{1}{4}, \text{ which gives } \frac{1}{3!} < \frac{1}{2^2}$$

$$\frac{1}{4!} = \frac{1}{24} \text{ and } \frac{1}{2^3} = \frac{1}{8}, \text{ which gives } \frac{1}{4!} < \frac{1}{2^3}$$

$$\frac{1}{5!} = \frac{1}{120} \text{ and } \frac{1}{2^4} = \frac{1}{16}, \text{ which gives } \frac{1}{5!} < \frac{1}{2^4}.$$

Therefore, by analogy, we can say that

$$\frac{1}{n!} < \frac{1}{2^{n-1}}$$
, when  $n > 2$ 

We observe that each term in (2) is less than the corresponding term in (3),

Therefore 
$$\left(\frac{1}{3!} + \frac{1}{4!} + \frac{1}{5!} + \dots + \frac{1}{n!}\right) < \left(\frac{1}{2^2} + \frac{1}{2^3} + \frac{1}{2^4} + \dots + \frac{1}{2^{n-1}} + \dots\right)$$
 ... (4)

Adding  $\left(1 + \frac{1}{1!} + \frac{1}{2!}\right)$  on both sides of (4), we get,
$$\left(1 + \frac{1}{1!} + \frac{1}{2!}\right) + \left(\frac{1}{3!} + \frac{1}{4!} + \frac{1}{5!} + \dots + \frac{1}{n!} + \dots\right)$$

$$< \left\{\left(1 + \frac{1}{1!} + \frac{1}{2!}\right) + \left(\frac{1}{2^2} + \frac{1}{2^3} + \frac{1}{2^4} + \dots + \frac{1}{2^{n-1}} + \dots\right)\right\}$$

$$= \left\{1 + \left(1 + \frac{1}{2} + \frac{1}{2^2} + \frac{1}{2^3} + \frac{1}{2^4} + \dots + \frac{1}{2^{n-1}} + \dots\right)\right\}$$

$$= 1 + \frac{1}{1 - \frac{1}{2}} = 1 + 2 = 3$$

Left hand side of (5) represents the series (1). Therefore e < 3 and also e > 2 and hence 2 < e < 3.

**Remark** The exponential series involving variable x can be expressed as

$$e^x = 1 + \frac{x}{1!} + \frac{x^2}{2!} + \frac{x^3}{3!} + \dots + \frac{x^n}{n!} + \dots$$

**Example 3** Find the coefficient of  $x^2$  in the expansion of  $e^{2x+3}$  as a series in powers of x.

Solution In the exponential series

$$e^x = 1 + \frac{x}{1!} + \frac{x^2}{2!} + \frac{x^3}{3!} + \dots$$

replacing x by (2x + 3), we get

series is

$$e^{2x+3} = 1 + \frac{(2x+3)}{1!} + \frac{(2x+3)^2}{2!} + \dots$$

Here, the general term is  $\frac{(2x+3)^n}{n!} = \frac{(3+2x)^n}{n!}$ . This can be expanded by the

Binomial Theorem as  $\frac{1}{n!} \left[ 3^n + {^nC_1} 3^{n-1} (2x) + {^nC_2} 3^{n-2} (2x)^2 + ... + (2x)^n \right].$ 

Here, the coefficient of  $x^2$  is  $\frac{{}^n C_2 3^{n-2} 2^2}{n!}$ . Therefore, the coefficient of  $x^2$  in the whole

 $\sum_{n=2}^{\infty} \frac{{}^{n}C_{2}3^{n-2}2^{2}}{n!} = 2\sum_{n=2}^{\infty} \frac{n(n-1)3^{n-2}}{n!}$   $= 2\sum_{n=2}^{\infty} \frac{3^{n-2}}{(n-2)!} \text{ [using } n! = n \ (n-1) \ (n-2)! \text{]}$   $= 2\left[1 + \frac{3}{1!} + \frac{3^{2}}{2!} + \frac{3^{3}}{3!} + \dots\right]$ 

Thus  $2e^3$  is the coefficient of  $x^2$  in the expansion of  $e^{2x+3}$ . Alternatively  $e^{2x+3} = e^3$ .  $e^{2x}$ 

$$= e^{3} \left[ 1 + \frac{2x}{1!} + \frac{(2x)^{2}}{2!} + \frac{(2x)^{3}}{3!} + \dots \right]$$

Thus, the coefficient of  $x^2$  in the expansion of  $e^{2x+3}$  is  $e^3 \cdot \frac{2^2}{2!} = 2e^3$ 

**Example 4** Find the value of  $e^2$ , rounded off to one decimal place.

Solution Using the formula of exponential series involving x, we have

$$e^{x} = 1 + \frac{x}{1!} + \frac{x^{2}}{2!} + \frac{x^{3}}{3!} + \dots + \frac{x^{n}}{n!} + \dots$$

Putting x = 2, we get

$$e^{2} = 1 + \frac{2}{1!} + \frac{2^{2}}{2!} + \frac{2^{3}}{3!} + \frac{2^{4}}{4!} + \frac{2^{5}}{5!} + \frac{2^{6}}{6!} + \dots$$
$$= 1 + 2 + 2 + \frac{4}{3} + \frac{2}{3} + \frac{4}{15} + \frac{4}{45} + \dots$$

 $\geq$  the sum of first seven terms  $\geq$  7.355.

On the other hand, we have

$$e^{2} < \left(1 + \frac{2}{1!} + \frac{2^{2}}{2!} + \frac{2^{3}}{3!} + \frac{2^{4}}{4!}\right) + \frac{2^{5}}{5!} \left(1 + \frac{2}{6} + \frac{2^{2}}{6^{2}} + \frac{2^{3}}{6^{3}} + \dots\right)$$

$$= 7 + \frac{4}{15} \left( 1 + \frac{1}{3} + \left( \frac{1}{3} \right)^2 + \dots \right) = 7 + \frac{4}{15} \left( \frac{1}{1 - \frac{1}{3}} \right) = 7 + \frac{2}{5} = 7.4.$$

Thus,  $e^2$  lies between 7.355 and 7.4. Therefore, the value of  $e^2$ , rounded off to one decimal place, is 7.4.

## A.1.5 Logarithmic Series

Another very important series is logarithmic series which is also in the form of infinite series. We state the following result without proof and illustrate its application with an example.

**Theorem** If |x| < 1, then

$$\log_e (1+x) = x - \frac{x^2}{2} + \frac{x^3}{3} - \dots$$

The series on the right hand side of the above is called the logarithmic series.

Note Note The expansion of  $\log_e (1+x)$  is valid for x = 1. Substituting x = 1 in the expansion of  $\log_e (1+x)$ , we get

$$\log_e 2 = 1 - \frac{1}{2} + \frac{1}{3} - \frac{1}{4} + \dots$$

**Example 5** If  $\alpha$ ,  $\beta$  are the roots of the equation  $x^2 - px + q = 0$ , prove that

$$\log_e \left( 1 + px + qx^2 \right) = \left( \alpha + \beta \right) x - \frac{\alpha^2 + \beta^2}{2} x^2 + \frac{\alpha^3 + \beta^3}{3} x^3 - \dots$$

Solution Right hand side 
$$= \left[\alpha x - \frac{\alpha^2 x^2}{2} + \frac{\alpha^3 x^3}{3} - \dots\right] + \left[\beta x - \frac{\beta^2 x^2}{2} + \frac{\beta^3 x^3}{3} - \dots\right]$$
$$= \log_e \left(1 + \alpha x\right) + \log\left(1 + \beta x\right)$$
$$= \log_e \left(1 + (\alpha + \beta)x + \alpha \beta x^2\right)$$
$$= \log_e \left(1 + px + qx^2\right) = \text{Left hand side.}$$

Here, we have used the facts  $\alpha + \beta = p$  and  $\alpha\beta = q$ . We know this from the given roots of the quadratic equation. We have also assumed that both  $|\alpha x| < 1$  and  $|\beta x| < 1$ .