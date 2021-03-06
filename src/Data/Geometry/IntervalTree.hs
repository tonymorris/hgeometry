{-# LANGUAGE TemplateHaskell #-}
module Data.Geometry.IntervalTree( NodeData(..)
                                 , splitPoint, intervalsLeft, intervalsRight
                                 , IntervalTree(..), unIntervalTree
                                 , IntervalLike(..)
                                 , createTree, fromIntervals
                                 , insert, delete
                                 , stab
                                 ) where

import           Control.Lens
import           Data.BinaryTree
import           Data.Ext
import           Data.Geometry.Interval
import           Data.Geometry.Properties
import qualified Data.List as List
import qualified Data.Map as M
import           Data.Range

--------------------------------------------------------------------------------

-- | Information stored in a node of the Interval Tree
data NodeData i r = NodeData { _splitPoint     :: !r
                             , _intervalsLeft  :: !(M.Map r [i])
                             , _intervalsRight :: !(M.Map r [i])
                             } deriving (Show,Eq,Ord)
makeLenses ''NodeData


-- | IntervalTree type, storing intervals of type i
newtype IntervalTree i r =
  IntervalTree { _unIntervalTree :: BinaryTree (NodeData i r) }
  deriving (Show,Eq)
makeLenses ''IntervalTree

-- | Given an ordered list of points, create an interval tree
--
-- $O(n)$
createTree     :: Ord r => [r] -> IntervalTree i r
createTree pts = IntervalTree . asBalancedBinTree
               . map (\m -> NodeData m mempty mempty) $ pts


-- | Build an interval tree
--
-- $O(n \log n)$
fromIntervals    :: (Ord r, IntervalLike i, NumType i ~ r)
                 => [i] -> IntervalTree i r
fromIntervals is = foldr insert (createTree pts) is
  where
    endPoints (toRange -> Range' a b) = [a,b]
    pts = List.sort . concatMap endPoints $ is

--------------------------------------------------------------------------------


-- | Find all intervals that stab x
--
-- $O(\log n + k)$, where k is the output size
stab                    :: Ord r => r -> IntervalTree i r -> [i]
stab x (IntervalTree t) = stab' t
  where
    stab' Nil = []
    stab' (Internal l (NodeData m ll rr) r)
      | x <= m    = let is = f (<= x) . M.toAscList $ ll
                    in is ++ stab' l
      | otherwise = let is = f (>= x) . M.toDescList $ rr
                    in is ++ stab' r
    f p = concatMap snd . List.takeWhile (p . fst)


--------------------------------------------------------------------------------

-- | Insert :
-- pre: the interval intersects some midpoint in the tree
--
-- $O(\log n)$
insert                    :: (Ord r, IntervalLike i, NumType i ~ r)
                          => i -> IntervalTree i r -> IntervalTree i r
insert i (IntervalTree t) = IntervalTree $ insert' t
  where
    ri@(Range' a b) = toRange i

    insert' Nil = Nil
    insert' (Internal l nd@(_splitPoint -> m) r)
      | m `inRange` ri = Internal l (insert'' nd) r
      | b <= m         = Internal (insert' l) nd r
      | otherwise      = Internal l nd (insert' r)

    insert'' (NodeData m l r) = NodeData m (M.insertWith (++) a [i] l)
                                           (M.insertWith (++) b [i] r)


-- | Delete an interval from the Tree
--
-- $O(\log n)$ (under some general position assumption)
delete :: (Ord r, IntervalLike i, NumType i ~ r, Eq i)
          => i -> IntervalTree i r -> IntervalTree i r
delete i (IntervalTree t) = IntervalTree $ delete' t
  where
    ri@(Range' a b) = toRange i

    delete' Nil = Nil
    delete' (Internal l nd@(_splitPoint -> m) r)
      | m `inRange` ri = Internal l (delete'' nd) r
      | b <= m         = Internal (delete' l) nd r
      | otherwise      = Internal l nd (delete' r)

    delete'' (NodeData m l r) = NodeData m (M.update f a l) (M.update f b r)
    f is = let is' = List.delete i is in if null is' then Nothing else Just is'



--------------------------------------------------------------------------------


-- | Anything that looks like an interval
class IntervalLike i where
  toRange :: i -> Range (NumType i)

instance IntervalLike (Range r) where
  toRange = id

instance IntervalLike (Interval p r) where
  toRange = fmap (^.core) . _unInterval



--------------------------------------------------------------------------------

-- test = fromIntervals [ closedInterval 0 10
--                      , closedInterval 5 15
--                      , closedInterval 1 4
--                      , closedInterval 3 9
--                      ]

-- closedInterval a b = ClosedInterval (ext a) (ext b)
