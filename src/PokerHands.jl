module PokerHands

export chances


using Cards
using Combinatorics
using Random
using StaticArrays

Base.isless(c1::Card, c2::Card) = Cards.rank(c1) < Cards.rank(c2)

const VALUES = Dict(
    'A' => 14,
    'K' => 13,
    'Q' => 12,
    'J' => 11,
    'T' => 10,
    '9' => 9,
    '8' => 8,
    '7' => 7,
    '6' => 6,
    '5' => 5,
    '4' => 4,
    '3' => 3,
    '2' => 2
)

const SUITS = Dict('c'=>0, 'd'=>1, 'h'=>2, 's'=>3)

const POKER_HANDS =
    (:highcard, :pair, :twopair, :set, :straight, :flush, :full, :poker, :straightflush)


"""
    parse_hand(s)

Parse a four-element string `s` as two-element `StaticVector`.
"""
parse_hand(s) = SVector(Card(VALUES[s[1]], SUITS[s[2]]), Card(VALUES[s[3]], SUITS[s[4]]))


"""
    type_value(s)

Get the poker hand value of `Symbol` `s`, where `s` can be in `$POKER_HANDS`, `:highcard`
returns `1` and `:straightflush` returns `9`.
"""
type_value(s) = findfirst(h -> h === s, POKER_HANDS)


"""
    PokerHand

A `struct` to store a poker hand of five cards including its type, which can be in
`$POKER_HANDS`.
"""
struct PokerHand
    type::Symbol
    cards::NTuple{5, Card}
end

type_value(p::PokerHand) = type_value(p.type)

"""
    PokerHand(cards)

Determine the type of poker hand for 5 cards `cards` and return a `PokerHand` of
respective type.
"""
function PokerHand(cards)
    sorted_cards = sort(cards, rev=true)
    sorted_ranks = Cards.rank.(sorted_cards)
    isflush = length(unique(Cards.suit.(cards))) == 1
    is_ace_straight = sorted_ranks == SVector{5}(14,5,4,3,2)
    isstraight = all(==(-1), diff(sorted_ranks)) || is_ace_straight
    if is_ace_straight
        sorted_cards = SVector{5}(circshift(sorted_cards, -1))
    end

    if isflush && isstraight
        return PokerHand(:straightflush, Tuple(sorted_cards))
    elseif isflush
        return PokerHand(:flush, Tuple(sorted_cards))
    elseif isstraight
        return PokerHand(:straight, Tuple(sorted_cards))
    end

    ucards = length(unique(sorted_ranks))
    if ucards == 2
        c1 = count_equal(sorted_ranks, 1)
        if c1 == 1
            return PokerHand(:poker, Tuple(circshift(sorted_cards, -1)))
        elseif c1 == 2
            return PokerHand(:full, Tuple(circshift(sorted_cards, -2)))
        elseif c1 == 3
            return PokerHand(:full, Tuple(sorted_cards))
        elseif c1 == 4
            return PokerHand(:poker, Tuple(sorted_cards))
        end
    elseif ucards == 3
        c1 = count_equal(sorted_ranks, 1)
        c2 = count_equal(sorted_ranks, c1 + 1)
        c3 = 5 - c1 - c2
        if c1 == 3
            return PokerHand(:set, Tuple(sorted_cards))
        elseif c2 == 3
            return PokerHand(
                :set,
                (
                    sorted_cards[2],
                    sorted_cards[1],
                    sorted_cards[3],
                    sorted_cards[4],
                    sorted_cards[5],
                ),
            )
        elseif c3 == 3
            return PokerHand(:set, Tuple(circshift(sorted_cards, -2)))
        elseif c1 == 1
            return PokerHand(:twopair, Tuple(circshift(sorted_cards, -1)))
        elseif c2 == 1
            return PokerHand(
                :twopair,
                (
                    sorted_cards[1],
                    sorted_cards[2],
                    sorted_cards[4],
                    sorted_cards[5],
                    sorted_cards[3],
                ),
            )
        else
            return PokerHand(:twopair, Tuple(sorted_cards))
        end
    elseif ucards == 4
        if sorted_ranks[1] == sorted_ranks[2]
            return PokerHand(:pair, Tuple(sorted_cards))
        elseif sorted_ranks[2] == sorted_ranks[3]
            return PokerHand(
                :pair,
                (
                    sorted_cards[2],
                    sorted_cards[3],
                    sorted_cards[1],
                    sorted_cards[4],
                    sorted_cards[5],
                ),
            )
        elseif sorted_ranks[3] == sorted_ranks[4]
            return PokerHand(
                :pair,
                (
                    sorted_cards[3],
                    sorted_cards[4],
                    sorted_cards[1],
                    sorted_cards[2],
                    sorted_cards[5],
                ),
            )
        else
            return PokerHand(:pair, Tuple(circshift(sorted_cards, -3)))
        end
    else
        return PokerHand(:highcard, Tuple(sorted_cards))
    end
end

"""
    count_equal(x, i)

Count how many elements in `x` are equal to its `i`th element.
`x` is assumed to be sorted and elements before `x[i]` are not considered.
"""
function count_equal(x, i)
    j = i + 1
    while x[j] == x[i]
        j += 1
    end
    return j - i
end


"""
    play(p, q)

Compares two `PokerHand`s `p` and `q` and returns `1` if `p` wins, `2` if `q` wins and `0`
for a split pot.
"""
function play(p, q)
    pv = type_value(p)
    qv = type_value(q)
    if pv < qv
        return 2
    elseif qv < pv
        return 1
    end
    for i in 1:5
        pr = Cards.rank(p.cards[i])
        qr = Cards.rank(q.cards[i])
        if pr < qr
            return 2
        elseif qr < pr
            return 1
        end
    end
    return 0
end


"""
    get_best_hand(cards)

Select the five cards of `cards` that provide the highest ranked `PokerHand` and return it.
"""
function get_best_hand(cards)
    current_hand = PokerHand(
        :highcard, (Card(2, 0), Card(3, 1), Card(4, 2), Card(5, 3), Card(7, 0))
    )
    for card in combinations(cards, 5)
        next_hand = PokerHand(card)
        if play(next_hand, current_hand) == 1
            current_hand = next_hand
        end
    end
    return current_hand
end

"""
    play(hand, others, flop)

Compares the `hand` to all hands in `others` considering the best possible poker hand
that can be built using the cards in `flop`.
Returns `1` if hand wins, `0` if `hand` splits the pot with any other hand and else `2`.
"""
function play(hand, others, flop)
    my_poker_hand = get_best_hand(SVector{7}(hand..., flop...))
    split = false
    for cards in others
        other_poker_hand = get_best_hand(SVector{7}(cards..., flop...))
        r = play(my_poker_hand, other_poker_hand)
        if r == 2
            return 2
        elseif r == 0
            split = true
        end
    end
    return split ? 0 : 1
end

"""
    function chances(hand, p=8; n=1000) -> (win, split)
   
Estimates the probabilites of `hand` winning against `p` other players, by simulating `n`
random games.
"""
function chances(hand, p=8; n=10000)
    all_cards = collect(Cards.deck)
    setdiff!(all_cards, hand)
    w, s = 0, 0
    for i in 1:n
        inds = randperm(50)
        others = Tuple(SVector{2}(all_cards[inds[2i-1:2i]]) for i in 1:p)
        flop = SVector{5}(all_cards[inds[2p+1:2p+5]])
        r = play(hand, others, flop)
        w += r==1
        s += r==0
    end
    return round((w / n) * 100, digits = 2), round((s / n) * 100, digits = 2)
end
chances(s::AbstractString, p=8; n=10000) = chances(parse_hand(s), p; n=n)

end

