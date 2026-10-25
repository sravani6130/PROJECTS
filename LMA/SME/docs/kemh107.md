# **BINOMIAL THEOREM**

**❖** Mathematics is a most exact science and its conclusions are capable of absolute proofs. − C.P. STEINMETZ**❖** 

#### 7.1 Introduction

In earlier classes, we have learnt how to find the squares and cubes of binomials like a + b and a - b. Using them, we could evaluate the numerical values of numbers like  $(98)^2 = (100 - 2)^2$ ,  $(999)^3 = (1000 - 1)^3$ , etc. However, for higher powers like  $(98)^5$ ,  $(101)^6$ , etc., the calculations become difficult by using repeated multiplication. This difficulty was overcome by a theorem known as binomial theorem. It gives an easier way to expand  $(a + b)^n$ , where n is an integer or a rational number. In this Chapter, we study binomial theorem for positive integral indices only.

![](_page_0_Picture_6.jpeg)

Blaise Pascal (1623-1662)

## **7.2** Binomial Theorem for Positive Integral Indices

Let us have a look at the following identities done earlier:

$$(a+b)^{0} = 1 a+b \neq 0$$

$$(a+b)^{1} = a+b$$

$$(a+b)^{2} = a^{2} + 2ab + b^{2}$$

$$(a+b)^{3} = a^{3} + 3a^{2}b + 3ab^{2} + b^{3}$$

$$(a+b)^{4} = (a+b)^{3} (a+b) = a^{4} + 4a^{3}b + 6a^{2}b^{2} + 4ab^{3} + b^{4}$$

In these expansions, we observe that

- (i) The total number of terms in the expansion is one more than the index. For example, in the expansion of  $(a + b)^2$ , number of terms is 3 whereas the index of  $(a + b)^2$  is 2.
- (ii) Powers of the first quantity 'a' go on decreasing by 1 whereas the powers of the second quantity 'b' increase by 1, in the successive terms.
- (iii) In each term of the expansion, the sum of the indices of a and b is the same and is equal to the index of a + b.

1

| Index | Coefficients |   |   |   |   |   |   |  |
|-------|--------------|---|---|---|---|---|---|--|
| 0     |              |   |   | 1 |   |   |   |  |
| 1     |              |   | 1 |   | 1 |   |   |  |
| 2     |              | 1 |   | 2 |   | 1 |   |  |
| 3     | 1            |   | 3 |   | 3 |   | 1 |  |

We now arrange the coefficients in these expansions as follows (Fig 7.1):

Do we observe any pattern in this table that will help us to write the next row? Yes we do. It can be seen that the addition of 1's in the row for index 1 gives rise to 2 in the row for index 2. The addition of 1, 2 and 2, 1 in the row for index 2, gives rise to 3 and 3 in the row for index 3 and so on. Also, 1 is present at the beginning and at the end of each row. This can be continued till any index of our interest.

Fig 7.1

We can extend the pattern given in Fig 7.2 by writing a few more rows.

![](_page_1_Figure_6.jpeg)

## Pascal's Triangle

The structure given in Fig 7.2 looks like a triangle with 1 at the top vertex and running down the two slanting sides. This array of numbers is known as *Pascal's triangle*, after the name of French mathematician Blaise Pascal. It is also known as *Meru Prastara* by Pingla.

Expansions for the higher powers of a binomial are also possible by using Pascal's triangle. Let us expand  $(2x + 3y)^5$  by using Pascal's triangle. The row for index 5 is

Using this row and our observations (i), (ii) and (iii), we get 
$$(2x + 3y)^5 = (2x)^5 + 5(2x)^4 (3y) + 10(2x)^3 (3y)^2 + 10 (2x)^2 (3y)^3 + 5(2x)(3y)^4 + (3y)^5$$
$$= 32x^5 + 240x^4y + 720x^3y^2 + 1080x^2y^3 + 810xy^4 + 243y^5.$$

Now, if we want to find the expansion of  $(2x + 3y)^{12}$ , we are first required to get the row for index 12. This can be done by writing all the rows of the Pascal's triangle till index 12. This is a slightly lengthy process. The process, as you observe, will become more difficult, if we need the expansions involving still larger powers.

We thus try to find a rule that will help us to find the expansion of the binomial for any power without writing all the rows of the Pascal's triangle, that come before the row of the desired index.

For this, we make use of the concept of combinations studied earlier to rewrite

the numbers in the Pascal's triangle. We know that  ${}^{n}C_{r} = \frac{n!}{r!(n-r)!}$ ,  $0 \le r \le n$  and

*n* is a non-negative integer. Also,  ${}^{n}C_{0} = 1 = {}^{n}C_{n}$ The Pascal's triangle can now be rewritten as (Fig 7.3)

| Index | Coefficients                                                                                                                                                          |
|-------|-----------------------------------------------------------------------------------------------------------------------------------------------------------------------|
| 0     | <sup>0</sup> C <sub>0</sub> (=1)                                                                                                                                      |
| 1     | $ \begin{array}{ccc}  & {}^{1}\mathbf{C}_{0} & {}^{1}\mathbf{C}_{1} \\  & (=1) & (=1) \end{array} $                                                                   |
| 2     | ${}^{2}\mathbf{C}_{0}$ ${}^{2}\mathbf{C}_{1}$ ${}^{2}\mathbf{C}_{2}$ (=1)                                                                                             |
| 3     | ${}^{3}\mathbf{C}_{0}$ ${}^{3}\mathbf{C}_{1}$ ${}^{3}\mathbf{C}_{2}$ ${}^{3}\mathbf{C}_{3}$ (=1)                                                                      |
| 4     | ${}^{4}\mathbf{C}_{0}$ ${}^{4}\mathbf{C}_{1}$ ${}^{4}\mathbf{C}_{2}$ ${}^{4}\mathbf{C}_{3}$ ${}^{4}\mathbf{C}_{4}$ (=1) (=4) (=1)                                     |
| 5     | ${}^{5}\mathbf{C}_{0}$ ${}^{5}\mathbf{C}_{1}$ ${}^{5}\mathbf{C}_{2}$ ${}^{5}\mathbf{C}_{3}$ ${}^{5}\mathbf{C}_{4}$ ${}^{5}\mathbf{C}_{5}$ (=1) $(=10)$ $(=10)$ $(=5)$ |

Fig 7.3 Pascal's triangle

Observing this pattern, we can now write the row of the Pascal's triangle for any index without writing the earlier rows. For example, for the index 7 the row would be

$${}^{7}C_{0}$$
  ${}^{7}C_{1}$   ${}^{7}C_{2}$   ${}^{7}C_{3}$   ${}^{7}C_{4}$   ${}^{7}C_{5}$   ${}^{7}C_{6}$   ${}^{7}C_{7}$ 

Thus, using this row and the observations (i), (ii) and (iii), we have

$$(a+b)^7 = {}^7\mathbf{C}_0 a^7 + 7\mathbf{C}_1 a^6 b + {}^7\mathbf{C}_2 a^5 b^2 + {}^7\mathbf{C}_3 a^4 b^3 + 7\mathbf{C}_4 a^3 b^4 + {}^7\mathbf{C}_5 a^2 b^5 + {}^7\mathbf{C}_6 a b^6 + {}^7\mathbf{C}_7 b^7$$

An expansion of a binomial to any positive integral index say n can now be visualised using these observations. We are now in a position to write the expansion of a binomial to any positive integral index.

#### 7.2.1 Binomial theorem for any positive integer n,

$$(a + b)^n = {^nC_0}a^n + {^nC_1}a^{n-1}b + {^nC_2}a^{n-2}b^2 + ... + {^nC_{n-1}}a.b^{n-1} + {^nC_n}b^n$$

**Proof** The proof is obtained by applying principle of mathematical induction.

Let the given statement be

P(n): 
$$(a + b)^n = {}^nC_0a^n + {}^nC_1a^{n-1}b + {}^nC_2a^{n-2}b^2 + ... + {}^nC_{n-1}a.b^{n-1} + {}^nC_nb^n$$
  
For  $n = 1$ , we have

P (1): 
$$(a + b)^1 = {}^{1}C_0a^1 + {}^{1}C_1b^1 = a + b$$

Thus, P(1) is true.

Suppose P(k) is true for some positive integer k, i.e.

Suppose 
$$f^{k}(k)$$
 is true for some positive integer  $k$ , i.e.
$$(a+b)^{k} = {}^{k}C_{0}a^{k} + {}^{k}C_{1}a^{k-1}b + {}^{k}C_{2}a^{k-2}b^{2} + ... + {}^{k}C_{k}b^{k} \qquad ...$$
(1)

We shall prove that P(k + 1) is also true, i.e.,

$$(a+b)^{k+1} = {}^{k+1}C_0 a^{k+1} + {}^{k+1}C_1 a^k b + {}^{k+1}C_2 a^{k-1}b^2 + ... + {}^{k+1}C_{k+1} b^{k+1}$$
Now,  $(a+b)^{k+1} = (a+b) (a+b)^k$ 

$$= (a+b) ({}^kC_0 a^k + {}^kC_1 a^{k-1} b + {}^kC_2 a^{k-2} b^2 + ... + {}^kC_{k-1} ab^{k-1} + {}^kC_k b^k)$$
[from (1)]
$$= {}^kC_0 a^{k+1} + {}^kC_1 a^k b + {}^kC_2 a^{k-1}b^2 + ... + {}^kC_{k-1} a^2 b^{k-1} + {}^kC_k ab^k + {}^kC_0 a^k b + {}^kC_1 a^{k-1}b^2 + {}^kC_2 a^{k-2}b^3 + ... + {}^kC_{k-1} ab^k + {}^kC_k b^{k+1}$$
[by actual multiplication]
$$= {}^kC_0 a^{k+1} + ({}^kC_1 + {}^kC_0) a^k b + ({}^kC_2 + {}^kC_1) a^{k-1} b^2 + ... + ({}^kC_k + {}^kC_{k-1}) ab^k + {}^kC_k b^{k+1}$$
[grouping like terms]
$$= {}^{k+1}C_0 a^{k+1} + {}^{k+1}C_1 a^k b + {}^{k+1}C_2 a^{k-1} b^2 + ... + {}^{k+1}C_k ab^k + {}^{k+1}C_{k+1} b^{k+1}$$
(by using  ${}^{k+1}C_0 = 1$ ,  ${}^kC_1 + {}^kC_2 = {}^{k+1}C_2$  and  ${}^kC_k = 1 = {}^{k+1}C_{k+1}$ )

Thus, it has been proved that P (k + 1) is true whenever P(k) is true. Therefore, by principle of mathematical induction, P(n) is true for every positive integer n.

We illustrate this theorem by expanding  $(x + 2)^6$ :

$$(x+2)^6 = {}^{6}C_{0}x^6 + {}^{6}C_{1}x^5.2 + {}^{6}C_{2}x^42^2 + {}^{6}C_{3}x^3.2^3 + {}^{6}C_{4}x^2.2^4 + {}^{6}C_{5}x.2^5 + {}^{6}C_{6}.2^6.$$
  
=  $x^6 + 12x^5 + 60x^4 + 160x^3 + 240x^2 + 192x + 64$ 

Thus 
$$(x + 2)^6 = x^6 + 12x^5 + 60x^4 + 160x^3 + 240x^2 + 192x + 64$$
.

#### **Observations**

1. The notation  $\sum_{k=0}^{n} {}^{n}C_{k} a^{n-k}b^{k}$  stands for

 ${}^{n}C_{0}a^{n}b^{0} + {}^{n}C_{1}a^{n-1}b^{1} + ... + {}^{n}C_{r}a^{n-r}b^{r} + ... + {}^{n}C_{n}a^{n-n}b^{n}$ , where  $b^{0} = 1 = a^{n-n}$ . Hence the theorem can also be stated as

$$(a+b)^n = \sum_{k=0}^n {^nC_k a^{n-k}b^k}$$

- 2. The coefficients <sup>n</sup>C<sub>r</sub> occurring in the binomial theorem are known as binomial coefficients.
- 3. There are (n+1) terms in the expansion of  $(a+b)^n$ , i.e., one more than the index.
- 4. In the successive terms of the expansion the index of a goes on decreasing by unity. It is n in the first term, (n-1) in the second term, and so on ending with zero in the last term. At the same time the index of b increases by unity, starting with zero in the first term, 1 in the second and so on ending with n in the last term.
- 5. In the expansion of  $(a+b)^n$ , the sum of the indices of a and b is n+0=n in the first term, (n-1)+1=n in the second term and so on 0+n=n in the last term. Thus, it can be seen that the sum of the indices of a and b is n in every term of the expansion.
- **7.2.2** Some special cases In the expansion of  $(a + b)^n$ ,
- (i) Taking a = x and b = -y, we obtain

$$(x - y)^{n} = [x + (-y)]^{n}$$

$$= {}^{n}C_{0}x^{n} + {}^{n}C_{1}x^{n-1}(-y) + {}^{n}C_{2}x^{n-2}(-y)^{2} + {}^{n}C_{3}x^{n-3}(-y)^{3} + \dots + {}^{n}C_{n}(-y)^{n}$$

$$= {}^{n}C_{0}x^{n} - {}^{n}C_{1}x^{n-1}y + {}^{n}C_{2}x^{n-2}y^{2} - {}^{n}C_{3}x^{n-3}y^{3} + \dots + (-1)^{n} {}^{n}C_{n}y^{n}$$

Thus  $(x-y)^n = {}^nC_0x^n - {}^nC_1x^{n-1}y + {}^nC_2x^{n-2}y^2 + ... + (-1)^n {}^nC_ny^n$ 

Using this, we have  $(x-2y)^5 = {}^5C_0x^5 - {}^5C_1x^4 (2y) + {}^5C_2x^3 (2y)^2 - {}^5C_3x^2 (2y)^3 + {}^5C_4x(2y)^4 - {}^5C_5(2y)^5$ 

$$= x^5 - 10x^4y + 40x^3y^2 - 80x^2y^3 + 80xy^4 - 32y^5$$

(ii) Taking a = 1, b = x, we obtain

$$(1+x)^n = {}^nC_0(1)^n + {}^nC_1(1)^{n-1}x + {}^nC_2(1)^{n-2}x^2 + \dots + {}^nC_nx^n$$
  
=  ${}^nC_0 + {}^nC_1x + {}^nC_2x^2 + {}^nC_3x^3 + \dots + {}^nC_nx^n$ 

Thus  $(1+x)^n = {}^nC_0 + {}^nC_1x + {}^nC_2x^2 + {}^nC_3x^3 + \dots + {}^nC_nx^n$ 

In particular, for x = 1, we have

$$2^{n} = {^{n}C_{0}} + {^{n}C_{1}} + {^{n}C_{2}} + \dots + {^{n}C_{n}}.$$

(iii) Taking a = 1, b = -x, we obtain

$$(1-x)^n = {}^nC_0 - {}^nC_1x + {}^nC_2x^2 - ... + (-1)^n {}^nC_nx^n$$

In particular, for x = 1, we get

$$0 = {}^{n}C_{0} - {}^{n}C_{1} + {}^{n}C_{2} - \dots + (-1)^{n} {}^{n}C_{n}$$

Example 1 Expand  $\left(x^2 + \frac{3}{x}\right)^4$ ,  $x \neq 0$ 

Solution By using binomial theorem, we have

$$x^{2} + \frac{3}{x} = {}^{4}C_{0}(x^{2})^{4} + {}^{4}C_{1}(x^{2})^{3} \left(\frac{3}{x}\right) + {}^{4}C_{2}(x^{2})^{2} \left(\frac{3}{x}\right)^{2} + {}^{4}C_{3}(x^{2}) \left(\frac{3}{x}\right)^{3} + {}^{4}C_{4} \left(\frac{3}{x}\right)^{4}$$

$$= x^{8} + 4 \cdot x^{6} \cdot \frac{3}{x} + 6 \cdot x^{4} \cdot \frac{9}{x^{2}} + 4 \cdot x^{2} \cdot \frac{27}{x^{3}} + \frac{81}{x^{4}}$$

$$= x^{8} + 12x^{5} + 54x^{2} + \frac{108}{x} + \frac{81}{x^{4}}.$$

## Example 2 Compute (98)<sup>5</sup>.

**Solution** We express 98 as the sum or difference of two numbers whose powers are easier to calculate, and then use Binomial Theorem.

Write 
$$98 = 100 - 2$$

Therefore, 
$$(98)^5 = (100 - 2)^5$$
  

$$= {}^5C_0 (100)^5 - {}^5C_1 (100)^4.2 + {}^5C_2 (100)^32^2$$

$$- {}^5C_3 (100)^2 (2)^3 + {}^5C_4 (100) (2)^4 - {}^5C_5 (2)^5$$

$$= 10000000000 - 5 \times 100000000 \times 2 + 10 \times 1000000 \times 4 - 10 \times 10000$$

$$\times 8 + 5 \times 100 \times 16 - 32$$

$$= 10040008000 - 1000800032 = 9039207968.$$

**Example 3** Which is larger (1.01)<sup>1000000</sup> or 10,000?

**Solution** Splitting 1.01 and using binomial theorem to write the first few terms we have

$$(1.01)^{1000000} = (1 + 0.01)^{1000000}$$
  
=  $^{1000000}$ C<sub>0</sub> +  $^{1000000}$ C<sub>1</sub>(0.01) + other positive terms  
= 1 + 1000000 × 0.01 + other positive terms  
= 1 + 10000 + other positive terms  
> 10000

**Example 4** Using binomial theorem, prove that  $6^n$ –5n always leaves remainder 1 when divided by 25.

**Solution** For two numbers a and b if we can find numbers q and r such that a = bq + r, then we say that b divides a with q as quotient and r as remainder. Thus, in order to show that  $6^n - 5n$  leaves remainder 1 when divided by 25, we prove that  $6^n - 5n = 25k + 1$ , where k is some natural number.

We have

Hence

$$(1+a)^n = {^nC_0} + {^nC_1}a + {^nC_2}a^2 + \dots + {^nC_n}a^n$$

For a = 5, we get

$$(1+5)^n = {^nC}_0 + {^nC}_15 + {^nC}_25^2 + \dots + {^nC}_n5^n$$

i.e. 
$$(6)^n = 1 + 5n + 5^2 \cdot {^nC_2} + 5^3 \cdot {^nC_3} + \dots + 5^n$$

 $(1.01)^{1000000} > 10000$ 

i.e. 
$$6^n - 5n = 1 + 5^2 ({}^nC_2 + {}^nC_3 + ... + 5^{n-2})$$

or 
$$6^n - 5n = 1 + 25 ({}^nC_2 + 5 . {}^nC_3 + ... + 5^{n-2})$$

or 
$$6^n - 5n = 25k + 1$$
 where  $k = {}^nC_2 + 5 \cdot {}^nC_3 + \dots + 5^{n-2}$ .

This shows that when divided by 25,  $6^n - 5n$  leaves remainder 1.

# **EXERCISE 7.1**

Expand each of the expressions in Exercises 1 to 5.

1. 
$$(1-2x)^5$$
 2.  $\left(\frac{2}{x} - \frac{x}{2}\right)^5$  3.  $(2x-3)^6$ 

4. 
$$\left(\frac{x}{3} + \frac{1}{x}\right)^5$$

5. 
$$\left(x+\frac{1}{x}\right)^6$$

Using binomial theorem, evaluate each of the following:

6.  $(96)^3$ 

- **7.** (102)<sup>5</sup>
- 8.  $(101)^4$

- **9.** (99)<sup>5</sup>
- 10. Using Binomial Theorem, indicate which number is larger  $(1.1)^{10000}$  or 1000.
- 11. Find  $(a+b)^4 (a-b)^4$ . Hence, evaluate  $(\sqrt{3} + \sqrt{2})^4 (\sqrt{3} \sqrt{2})^4$ .
- 12. Find  $(x+1)^6 + (x-1)^6$ . Hence or otherwise evaluate  $(\sqrt{2} + 1)^6 + (\sqrt{2} 1)^6$ .
- 13. Show that  $9^{n+1} 8n 9$  is divisible by 64, whenever *n* is a positive integer.
- **14.** Prove that  $\sum_{r=0}^{n} 3^{r} {}^{n}C_{r} = 4^{n}$ .

# Miscellaneous Exercise on Chapter 7

1. If a and b are distinct integers, prove that a - b is a factor of  $a^n - b^n$ , whenever n is a positive integer.

[Hint write  $a^n = (a - b + b)^n$  and expand]

- 2. Evaluate  $(\sqrt{3} + \sqrt{2})^6 (\sqrt{3} \sqrt{2})^6$ .
- 3. Find the value of  $\left(a^2 + \sqrt{a^2 1}\right)^4 + \left(a^2 \sqrt{a^2 1}\right)^4$ .
- 4. Find an approximation of  $(0.99)^5$  using the first three terms of its expansion.
- 5. Expand using Binomial Theorem  $\left(1 + \frac{x}{2} \frac{2}{x}\right)^4$ ,  $x \ne 0$ .
- **6.** Find the expansion of  $(3x^2 2ax + 3a^2)^3$  using binomial theorem.

#### **Summary**

- ♦ The expansion of a binomial for any positive integral n is given by Binomial Theorem, which is  $(a + b)^n = {}^nC_0a^n + {}^nC_1a^{n-1}b + {}^nC_2a^{n-2}b^2 + ... + {}^nC_{n-1}a.b^{n-1} + {}^nC_nb^n$ .
- ◆ The coefficients of the expansions are arranged in an array. This array is called *Pascal's triangle*.

#### Historical Note

The ancient Indian mathematicians knew about the coefficients in the expansions of  $(x + y)^n$ ,  $0 \le n \le 7$ . The arrangement of these coefficients was in the form of a diagram called *Meru-Prastara*, provided by Pingla in his book *Chhanda shastra* (200B.C.). This triangular arrangement is also found in the work of Chinese mathematician Chu-shi-kie in 1303. The term binomial coefficients was first introduced by the German mathematician, Michael Stipel (1486-1567) in approximately 1544. Bombelli (1572) also gave the coefficients in the expansion of  $(a + b)^n$ , for n = 1, 2, ..., 7 and Oughtred (1631) gave them for n = 1, 2, ..., 10. The arithmetic triangle, popularly known as *Pascal's triangle* and similar to the *Meru-Prastara* of Pingla was constructed by the French mathematician Blaise Pascal (1623-1662) in 1665.

The present form of the binomial theorem for integral values of *n* appeared in *Trate du triange arithmetic*, written by Pascal and published posthumously in 1665

![](_page_8_Picture_5.jpeg)