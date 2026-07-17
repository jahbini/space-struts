# Finding Our Way Home

The previous stepping stone taught us that a builder and a surveyor look at the same world from different points of view. The builder remembers how the structure was assembled. The surveyor remembers where the finished structure stands. Neither description is better than the other, because each answers a different question.

A builder naturally asks,

> *How did I get here?*

A surveyor asks,

> *Where am I?*

Here both questions have exact answers, and we never leave the language of the dodecahedron to give them.

A dodecahedron shows six directions to the world — one for every pair of opposite faces. Any point we care to speak of is completely described by six numbers: how far the point lies from each of the six faces. We write them as

\[
[a,\;b,\;c,\;d,\;e,\;f].
\]

Each number is an exact golden-ratio quantity — never rounded, never approximated. Together, the six face-distances name the point exactly and completely. This is the surveyor's record.

The builder's record is different. It is the sequence of moves that reached the point. Each move steps along one of the six face-directions, and each move changes the six face-distances by a fixed, exact amount — that direction's own signature. To build is simply to add signatures. The six numbers gather the entire history of the construction, exactly, with nothing lost.

## Building by Adding

Begin at the center, where every face is equally far away:

\[
[z,\;z,\;z,\;z,\;z,\;z].
\]

A single step along the first face-direction adds that direction's signature to the six numbers. A second step adds the same signature again. The construction grows, and the six numbers grow with it, and at every moment the surveyor can read the point's exact place straight from them.

Nothing has been approximated.

Nothing has been forgotten.

## Coming Home

The real question is whether we can always find our way home. Suppose we have wandered deep into a construction and hold nothing but the six face-distances. Have we lost the way back?

Not at all. The six numbers *are* the way back.

To undo a move, subtract its signature. To return all the way to the beginning, subtract the moves in reverse order. Nothing is approximated along the way, because the six faces have been watching the whole time. A dodecahedron never forgets where its faces are, and so a point described by its six faces is never truly lost.

## The Reward of Remembering the Faces

There is one more reward for speaking in the language of the six faces.

Suppose we want the mirror image of a point. A mirror of the dodecahedron does not measure and does not compute. It simply relabels the faces — sending each face to another, and for some, reversing a direction. And because our point is nothing but its six face-distances, the mirror image of the point is nothing but those same six numbers, shuffled the way the mirror shuffles the faces.

Here is one mirror of the dodecahedron:

\[
[a,\;b,\;c,\;d,\;e,\;f]
\;\longrightarrow\;
[c,\;f,\;a,\;d,\;e,\;b].
\]

Look closely at what it does. The distance to the first face becomes the distance to the third. The distance to the second face becomes the distance to the sixth. The fourth and fifth faces are left where they are. The mirror has reached across the solid and traded faces that are not opposite each other — face one for face three, face two for face six.

That reaching-across is the whole point. A mere flip along an axis can only trade a face for the face directly across from it. A true mirror of the dodecahedron does more: it carries a face to one of its *neighbors*. This is the five-fold nature of the solid showing itself — something no flat axis-flip can imitate. And still, the mirror image is found without a single measurement. We only rearranged the six numbers.

There are fifteen such mirrors in all, and each is its own shuffle of the six faces. Nothing is measured. Nothing is approximated. The builder reads the mirror's shuffle and applies it.

## One Face, and a Warning

One caution completes the picture, and it is a gift rather than a nuisance.

Reflecting across the flat plane of a single face — not one of the dodecahedron's fifteen mirror symmetries, but one face's own plane — is a different act. When we try it, the arithmetic will not come out even: the answer must be divided by the number φ+2, and φ+2 refuses to divide our whole numbers cleanly, leaving a stubborn five behind. That stubborn divisor is a signal, kin to the scale-mismatch signal we have met before: it tells us the mirror image of that point does not land on the construction lattice at all.

So the clean reflections — the ones that stay exact and stay on the lattice — are exactly the mirror symmetries that shuffle the six faces. When a reflection would carry us off the lattice, the arithmetic says so immediately and exactly, with that φ+2 underneath. We are never left guessing.

## Builder's Notebook

Take a point given by its six face-distances, say

\[
[1,\;0,\;2,\;0,\;0,\;3].
\]

Apply the mirror

\[
[a,\;b,\;c,\;d,\;e,\;f]
\;\longrightarrow\;
[c,\;f,\;a,\;d,\;e,\;b]
\]

by hand. Reading the rule off carefully, you should reach

\[
[2,\;3,\;1,\;0,\;0,\;0].
\]

Notice that you never once had to measure anything, and notice *where the numbers went*: the value at face one landed on face three, and the value at face two landed on face six. The mirror carried each face to a neighbor, not to its opposite. That is a real dodecahedral reflection, and it is nothing more than moving six numbers around.

Now try to reflect the same point across a single face's own plane, and watch that φ+2 appear underneath, refusing to divide out. The arithmetic is telling you something exact: that image lies off the lattice.

The difficult part was choosing to remember all six faces. Once that is done, the mirror is almost effortless — and the arithmetic even warns us when a mirror would carry us away from the lattice.

## Looking Ahead

We now have a language that measures exactly, remembers exactly, finds its way home exactly, and turns a point into its mirror image with very little effort — all without ever leaving the six faces of the dodecahedron.

But one move still eludes us: the *flip* — a mirror across a face's own plane — is the one that left that stubborn φ+2 behind, off the lattice. Is the flip truly beyond us, or is that divisor a door rather than a wall?

The next stepping stone opens it.
