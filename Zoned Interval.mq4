//+------------------------------------------------------------------+
//|                                         Zoned Trading Window.mq4 |
//|                                                             Lung |
//|                                    https://github.com/lungstudio |
//+------------------------------------------------------------------+
#property copyright "Lung"
#property link "https://github.com/lungstudio"
#property version "1.00"
#property strict

enum TRADE_MODE
{
  BUY,
  SELL
};

enum TRADE_TYPE
{
  STOP,
  LIMIT
};

//--- input parameters
input double Interval = 100;
input double OffsetValue = 0;
input int NumberOfStopEntryOrders = 3;
input int NumberOfLimitOrders = 3;
input double Stack = 1;
input double TakeProfit = 100;
input double UpperLimit=100000000;
input double LowerLimit=0;
input TRADE_MODE Mode = BUY;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
{
  //---

  //---
  return (INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
  //---
}

void GetStopEntryOrderPrices(double currentPrice, double lowerLimit, double upperLimit, int noOfOrders, double &stopEntryOrderPrices[])
{
  if (currentPrice < lowerLimit || currentPrice > upperLimit) {
    return;
  }

  ArrayResize(stopEntryOrderPrices, noOfOrders);

  double intervalRatio = GetIntervalRatio(currentPrice);
  int n = Ceiling(intervalRatio);

  // edge case handling, when the price is divisible by the interval
  // i.e. the ratio is an integer
  if (MathMod(intervalRatio, 1) == 0) {
    n += 1;
  }

  for (int i = 0; i < ArraySize(stopEntryOrderPrices); i++)
  {
    double p = Interval * (n + i) + OffsetValue;
    stopEntryOrderPrices[i] = p;
  }
}

void GetlimitOrderPrices(double currentPrice, double lowerLimit, double upperLimit, int noOfOrders, double &limitOrderPrices[])
{
  if (currentPrice < lowerLimit || currentPrice > upperLimit) {
    return;
  }

  ArrayResize(limitOrderPrices, noOfOrders);

  double intervalRatio = GetIntervalRatio(currentPrice);
  int n = Floor(intervalRatio);

  // edge case handling, when the price is divisible by the interval
  // i.e. the ratio is an integer
  if (MathMod(intervalRatio, 1) == 0) {
    n -= 1;
  }

  for (int i = 0; i < ArraySize(limitOrderPrices); i++)
  {
    double p = Interval * (n - i) + OffsetValue;
    limitOrderPrices[i] = p;
  }
}

double GetIntervalRatio(double currentPrice)
{
  return (currentPrice - OffsetValue) / Interval;
}

int Ceiling(double value)
{
  int intValue = (int)value;
  int result = value > intValue ? intValue + 1 : intValue;
  return result;
}

int Floor(double value)
{
  int intValue = (int)value;
  int result = value >= intValue ? intValue : intValue - 1;
  return result;
}

void CheckAndCreateOpenOrders(TRADE_TYPE type, double &prices[], double takeProfit)
{
  if (ArraySize(prices) == 0) {
    return;
  }
  
  double tradablePrices[];
  DeepCopyArray(prices, tradablePrices);

  // check for tradable prices
  for (int i = 0; i < OrdersTotal(); i++)
  {
    if (ArraySize(tradablePrices) == 0) {
      break;
    }
    
    // check existing open order
    bool ok = OrderSelect(i, SELECT_BY_POS, MODE_TRADES);
    if (!ok) {
      Print("[Error] OrderSelect Error!");
      return;
    }

    // check order symbol
    if (OrderSymbol() != Symbol()) {
      continue;
    }

    // check type
    if (Mode == BUY) {
      if (type == STOP && OrderType() != OP_BUYSTOP) {
        continue;
      } else if (type == LIMIT && OrderType() != OP_BUYLIMIT) {
        continue;
      }
    } else {
      if (type == STOP && OrderType() != OP_SELLSTOP) {
        continue;
      } else if (type == LIMIT && OrderType() != OP_SELLLIMIT) {
        continue;
      }
    }

    for(int j = 0; j < ArraySize(tradablePrices); j++) {
      if (IsApproximatelyEqual(OrderOpenPrice(), tradablePrices[j])) {
        RemoveItemFromArray(tradablePrices, j);
        break;
      }
    }
  }

  // for debug purposes
  // string t = "";
  // for (int i = 0; i < ArraySize(tradablePrices); i++)
  // {
  //   t += (type == STOP ? "[STOP]" : "[LIMIT]") + "Final tradablePrices[" + IntegerToString(i) + "]: " + DoubleToString(tradablePrices[i]) + "\n";
  // }
  // Print(t);

  // create order with tradable prices
  int cmd;

  if (Mode == BUY) {
    cmd = (type == STOP) ? OP_BUYSTOP : OP_BUYLIMIT;
  } else {
    cmd = (type == STOP) ? OP_SELLSTOP : OP_SELLLIMIT;
  }

  for (int i = 0; i < ArraySize(tradablePrices); i++)
  {
    double tp = (Mode == BUY) ? tradablePrices[i] + takeProfit : tradablePrices[i] - takeProfit;
    int ticketNumber = OrderSend(Symbol(), cmd, Stack, tradablePrices[i], 0, 0, tp);
    if (ticketNumber == -1) {
      Print("[Error] failed to OrderSend, price: " + DoubleToString(tradablePrices[i]));
      break;
    }
  }

  // free arrays
  ArrayFree(tradablePrices);
}

void RemoveItemFromArray(double& array[], int index)
{
    int arraySize = ArraySize(array);

    if (index < 0 || index >= arraySize)
    {
        Print("Invalid index. Item removal failed.");
        return;
    }

    // Shift elements to the left, overwriting the item to remove
    for (int i = index; i < arraySize - 1; i++)
    {
        array[i] = array[i + 1];
    }

    // Reduce the size of the array
    ArrayResize(array, arraySize - 1);
}

void DeepCopyArray(double &sourceArray[], double &destinationArray[])
{
    int size = ArraySize(sourceArray);
    ArrayResize(destinationArray, size);

    for (int i = 0; i < size; i++)
    {
        destinationArray[i] = sourceArray[i];
    }
}

void CombineArrays(double &dest[], double &source1[], double &source2[])
{
  for (int i = 0; i < ArraySize(source1); i++)
  {
    dest[i] = source1[i];
  }

  for (int i = 0; i < ArraySize(source2); i++)
  {
    dest[ArraySize(source1) + i] = source2[i];
  }
}

// sometimes when we compare the price, it may return false even if the value "looks" the same
// it is due to precision issue by floating point
// this function avoid the precision issue
bool IsApproximatelyEqual(double actualValue, double expectedValue, double maxTolerance=0.05)
{
    double tolerance = MathAbs(actualValue - expectedValue) / expectedValue;
    return tolerance <= maxTolerance;
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
  // check if market is open
  if (!IsTradeAllowed()) {
    return;
  }

  //---
  double priceBid = MarketInfo(Symbol(), MODE_BID);
  double priceAsk = MarketInfo(Symbol(), MODE_ASK);

  // calculate the stopEntry and limitOrder prices
  double price;
  double stopEntryOrderPrices[];
  double limitOrderPrices[];
  if (Mode == BUY) {
    price = priceBid;
    GetStopEntryOrderPrices(price, LowerLimit, UpperLimit, NumberOfStopEntryOrders, stopEntryOrderPrices);
    GetlimitOrderPrices(price, LowerLimit, UpperLimit, NumberOfLimitOrders, limitOrderPrices);

  } else {
    // hack: sell mode, reverse the SE and LO
    price = priceAsk;
    GetStopEntryOrderPrices(price, LowerLimit, UpperLimit, NumberOfLimitOrders, limitOrderPrices);
    GetlimitOrderPrices(price, LowerLimit, UpperLimit, NumberOfStopEntryOrders, stopEntryOrderPrices);
  }

  // check & create stop orders
  CheckAndCreateOpenOrders(STOP, stopEntryOrderPrices, TakeProfit);

  // check & create limit orders
  CheckAndCreateOpenOrders(LIMIT, limitOrderPrices, TakeProfit);

  // for debug purposes
  // string seoStr = "";
  // for (int i = ArraySize(stopEntryOrderPrices) - 1; i >= 0; i--)
  // {
  //   seoStr += "SEO[" + IntegerToString(i) + "]: " + DoubleToString(stopEntryOrderPrices[i]) + "\n";
  // }
  // string loStr = "";
  // for (int i = 0; i < ArraySize(limitOrderPrices); i++)
  // {
  //   seoStr += "LO[" + IntegerToString(i) + "]: " + DoubleToString(limitOrderPrices[i]) + "\n";
  // }
  // Print(seoStr + loStr);


  // free arrays
  ArrayFree(stopEntryOrderPrices);
  ArrayFree(limitOrderPrices);
}
//+------------------------------------------------------------------+
