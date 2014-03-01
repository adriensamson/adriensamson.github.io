---
layout: post
title: Composer slowness analysis
---
## Intro
Everybody knows Composer is slow. Some benchmarks states that running it with HHVM may be 10 times faster.
But the real questions are why is it slow and how can we optimize it.

## Profiling

The first thing to do is to find why Composer is so slow. The `--profile` does not helps, it just shows you how slow it is and how many memory it uses.
So I decided to run composer through facebook's xhprof to find which parts are slowing it down.

### Methodology

Under debian unstable, installing the xhprof extension is as easy as `sudo aptitude install php5-xhprof && sudo php5enmod xhprof`.
I [tweaked](https://github.com/adriensamson/composer/compare/xhprof) composer to enable xhprof and save the profiling data.
I then ran `composer update` twice and keep only the second run data to profile only the solver part and not the installation one.

## Results

On composer itself, I saw that the *red square* was on `Composer\DependencyResolver\Pool::match` called by `Composer\DependencyResolver\Pool::computeWhatProvides`. These methods are called when building the dependency graph, which is probably not what takes so long time on large projects.
Then I profiled composer on the Symfony Standard Edition (v2.4.2). To make it slower, I also added `"minimum-stability": "dev", "prefer-stable": true` to the composer.json.

In these callgraphs, the *red square* was on `Composer\DependencyResolver\Rule::getLiterals` or `Composer\DependencyResolver\RuleSet::ruleById`. These methods are really **really** simple: they only return a property or an array item on a property. They **can't** be optimized. But what makes them appear in the *red square* is their total number of calls: more than 400000 in the symfonystandard-dev case!

To check the difference with running composer on HHVM, I also ran these profilings on HHVM compiled with `-DHOTPROFILER=ON` to get xhprof working. We can see that with HHVM these method calls are a lot less heavy than with PHP and the critical part comes back to `Composer\DependencyResolver\Pool::computeWhatProvides`.

I see two ways to optimize Composer:
* lower down the number of method calls to `ruleById` and `getLiterals` by lowering the number of rules,
* lower down the calls to `Composer\DependencyResolver\Pool::match` from `Composer\DependencyResolver\Pool::computeWhatProvides`.

## Callgraphs

| case | PHP 5.5 | HHVM |
| ---- | ------- | ---- |
| Composer | [13s](/images/composer/callgraph.composer.php.png) | [14s](/images/composer/callgraph.composer.hhvm.png) |
| Symfony Standard | [30s](/images/composer/callgraph.symfonystandard.php.png) | [23s](/images/composer/callgraph.symfonystandard.hhvm.png) |
| Symfony Standard with dev | [56s](/images/composer/callgraph.symfonystandard-dev.php.png) | [21s](/images/composer/callgraph.symfonystandard-dev.hhvm.png) |

