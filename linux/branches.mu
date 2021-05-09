fn foo {
  $foo: {
    break-if-=
    break-if-= $foo
    break-if-!=
    break-if-!= $foo
    break-if-<=
    break-if-<= $foo
    break-if->=
    break-if->= $foo
    break-if-<
    break-if-< $foo
    break-if->
    break-if-> $foo
    break-if-carry
    break-if-carry $foo
    break-if-overflow
    break-if-overflow $foo
    loop-if-=
    loop-if-= $foo
    loop-if-!=
    loop-if-!= $foo
    loop-if-<=
    loop-if-<= $foo
    loop-if->=
    loop-if->= $foo
    loop-if-<
    loop-if-< $foo
    loop-if->
    loop-if-> $foo
    loop-if-carry
    loop-if-carry $foo
    loop-if-not-carry
    loop-if-not-carry $foo
    loop-if-overflow
    loop-if-overflow $foo
    loop-if-not-overflow
    loop-if-not-overflow $foo
  }
}
