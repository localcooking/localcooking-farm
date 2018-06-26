module Main where

import Colors (palette)
import User (UserDetails (..), PreUserDetails (..))
import Spec.Topbar.Buttons (topbarButtons)
import Spec.Drawers.Buttons (drawersButtons)
import Spec.Content (content)
import Spec.Content.UserDetails (userDetails)
import Spec.Content.UserDetails.Buttons (userDetailsButtons)
import Spec.Snackbar (messages)
import LocalCooking.Types.ServerToClient (env)
import LocalCooking.Main (defaultMain)
import LocalCooking.Spec.Misc.Branding (mainBrand)
import LocalCooking.Dependencies.Farm (farmDependencies, newFarmQueues)
import LocalCooking.Dependencies.Tag (tagDependencies, newTagQueues)
import LocalCooking.Global.Links.Internal (ImageLinks (Logo40Png))

import Prelude
import Data.Maybe (Maybe (..))
import Data.UUID (GENUUID)
import Data.URI.Location (toLocation)
import Data.Argonaut.JSONUnit (JSONUnit (..))
import Control.Monad.Aff (sequential)
import Control.Monad.Eff (Eff)
import Control.Monad.Eff.Now (NOW)
import Control.Monad.Eff.Timer (TIMER)
import Control.Monad.Eff.Exception (EXCEPTION)
import Control.Monad.Eff.Ref (REF)
import Control.Monad.Eff.Console (CONSOLE, log)
import Control.Execution.Immediate (SET_IMMEDIATE_SHIM)

import React.DOM (text) as R
import MaterialUI.InjectTapEvent (INJECT_TAP_EVENT)
import MaterialUI.Button (button)
import MaterialUI.Button as Button
import MaterialUI.SvgIcon (svgIcon)
import MaterialUI.SvgIcon as SvgIcon
import MaterialUI.Types (createStyles)
import DOM (DOM)
import DOM.HTML.Types (HISTORY)
import WebSocket (WEBSOCKET)
import Network.HTTP.Affjax (AJAX)
import Browser.WebStorage (WEB_STORAGE)
import Crypto.Scrypt (SCRYPT)
import Queue.Types (readOnly, writeOnly)
import Queue.One as One
import Sparrow.Client.Queue (mountSparrowClientQueuesSingleton)



-- | All top-level effects
type Effects =
  ( console            :: CONSOLE
  , injectTapEvent     :: INJECT_TAP_EVENT
  , set_immediate_shim :: SET_IMMEDIATE_SHIM
  , ref                :: REF
  , dom                :: DOM
  , timer              :: TIMER
  , uuid               :: GENUUID
  , exception          :: EXCEPTION
  , history            :: HISTORY
  , now                :: NOW
  , ws                 :: WEBSOCKET
  , ajax               :: AJAX
  , webStorage         :: WEB_STORAGE
  , scrypt             :: SCRYPT
  )


main :: Eff Effects Unit
main = do
  log "Starting Local Cooking Farms frontend..."

  farmQueues <- newFarmQueues
  tagQueues <- newTagQueues
  siteErrorQueue <- One.newQueue

  searchMealTagsDeltaInQueue <- writeOnly <$> One.newQueue
  searchMealTagsInitInQueue <- writeOnly <$> One.newQueue

  let searchMealTagsOnDeltaOut deltaOut = case deltaOut of
        Nothing -> pure unit
          -- One.putQueue globalErrorQueue (GlobalErrorSecurity SecuritySaveFailed)
          -- FIXME subsidiary specific error queue
        Just mealTags -> pure unit
          -- apply result to queue that targets that ui component
      searchMealTagsOnInitOut mInitOut = case mInitOut of
        Nothing -> pure unit
          -- FIXME apply to mitch error queue
        Just JSONUnit -> pure unit

  _ <- mountSparrowClientQueuesSingleton tagQueues.searchMealTagsQueues
    searchMealTagsDeltaInQueue searchMealTagsInitInQueue searchMealTagsOnDeltaOut searchMealTagsOnInitOut
  -- One.onQueue searchMealTagKillificator \_ -> killSearchMealTagSub -- hack applied

  -- Top-level delta in issuer
  let searchMealTagDeltaIn :: String -> Eff Effects Unit
      searchMealTagDeltaIn = One.putQueue searchMealTagsDeltaInQueue

      -- searchMealTagInitIn :: JSONUnit -> Eff Effects Unit
      -- searchMealTagInitIn = One.putQueue searchMealTagsInitInQueue
      -- FIXME invoke immediately?


  One.putQueue searchMealTagsInitInQueue JSONUnit


  defaultMain
    { env
    , palette
    , siteQueues: {farmQueues,tagQueues}
    , deps: \{farmQueues,tagQueues} -> do
        farmDependencies farmQueues
        tagDependencies tagQueues
    , extraRedirect: \_ _ -> Nothing
    , leftDrawer:
      { buttons: drawersButtons
      }
    , topbar:
      { imageSrc: toLocation Logo40Png
      , buttons: topbarButtons
      }
    , content: content
    , userDetails:
      { buttons: userDetailsButtons
      , content: userDetails
      , obtain: \{user} -> do
        PreUserDetails mUser <- sequential $ PreUserDetails <$> user
        case mUser of
          Just user -> pure $ Just $ UserDetails {user}
          _ -> pure Nothing
      }
    , error:
      { content: messages {siteErrorQueue: readOnly siteErrorQueue}
      }
    , extendedNetwork:
      [ Button.withStyles
        (\_ ->
          { root: createStyles
            { background: "#c62828"
            , color: "#fff"
            , textTransform: "none"
            , "&:hover":
              { background: "#ff5f52"
              }
            }
          }
        )
        \{classes} ->
          button
          { href: "https://localcooking.com/"
          , classes: Button.createClasses classes
          , variant: Button.raised
          }
          [ svgIcon
            { viewBox: "0 0 279 279"
            , color: SvgIcon.inherit
            }
            [ mainBrand
            ]
          , R.text " Customers"
          ]
      , R.text " "
      , Button.withStyles
        (\_ ->
          { root: createStyles
            { background: "#1565c0"
            , color: "#fff"
            , textTransform: "none"
            , "&:hover":
              { background: "#5e92f3"
              }
            }
          }
        )
        \{classes} ->
          button
          { href: "https://chef.localcooking.com/"
          , classes: Button.createClasses classes
          , variant: Button.raised
          }
          [ svgIcon
            { viewBox: "0 0 279 279"
            , color: SvgIcon.inherit
            }
            [ mainBrand
            ]
          , R.text " Chefs"
          ]
      , R.text " "
      , Button.withStyles
        (\_ ->
          { root: createStyles
            { background: "#7b1fa2"
            , color: "#fff"
            , textTransform: "none"
            , "&:hover":
              { background: "#ae52d4"
              }
            }
          }
        )
        \{classes} ->
          button
          { href: "https://restaurant.localcooking.com/"
          , classes: Button.createClasses classes
          , variant: Button.raised
          }
          [ svgIcon
            { viewBox: "0 0 279 279"
            , color: SvgIcon.inherit
            }
            [ mainBrand
            ]
          , R.text " Restaurants"
          ]
      ]
    }
