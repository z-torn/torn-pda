import 'dart:async';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:sliding_up_panel/sliding_up_panel.dart';
import 'package:torn_pda/models/travel/foreign_stock_in.dart';
import 'package:torn_pda/models/items_model.dart';
import 'package:torn_pda/providers/theme_provider.dart';
import 'package:torn_pda/models/travel/foreign_stock_sort.dart';
import 'package:torn_pda/utils/shared_prefs.dart';
import 'package:torn_pda/widgets/stock_options_dialog.dart';
import 'package:http/http.dart' as http;
import 'dart:ui';

import 'package:torn_pda/utils/api_caller.dart';

class ForeignStockPage extends StatefulWidget {
  final String apiKey;

  ForeignStockPage({@required this.apiKey});

  @override
  _ForeignStockPageState createState() => _ForeignStockPageState();
}

class _ForeignStockPageState extends State<ForeignStockPage> {
  PanelController _pc = new PanelController();

  final double _initFabHeight = 25.0;
  double _fabHeight;
  double _panelHeightOpen = 300;
  double _panelHeightClosed = 75.0;

  ThemeProvider _themeProvider;

  Future _apiCalled;
  bool _apiSuccess;

  var _filteredStocks = ForeignStockInModel();
  var _allStocks = ForeignStockInModel();
  ItemsModel _allTornItems;

  int _capacity;

  final _filteredTypes = List<bool>.filled(4, true, growable: false);
  final _filteredFlags = List<bool>.filled(12, true, growable: false);

  String _countriesFilteredText = '';
  List<String> _countryCodes = [
    'ARG',
    'CAN',
    'CAY',
    'CHN',
    'HAW',
    'JPN',
    'MEX',
    'AFR',
    'SWI',
    'UAE',
    'UK',
  ];

  String _typesFilteredText = '';
  List<String> _typeCodes = [
    'Flowers',
    'Plushies',
    'Drugs',
    'Others',
  ];

  var _currentSort;
  final _popupChoices = <StockSort>[
    StockSort(type: StockSortType.country),
    StockSort(type: StockSortType.name),
    StockSort(type: StockSortType.type),
    StockSort(type: StockSortType.price),
    StockSort(type: StockSortType.value),
    StockSort(type: StockSortType.profit),
  ];

  @override
  void initState() {
    super.initState();
    _fabHeight = _initFabHeight;
    _apiCalled = _fetchApiInformation();
    _restoreSharedPreferences();
  }

  @override
  Widget build(BuildContext context) {
    _themeProvider = Provider.of<ThemeProvider>(context, listen: true);
    return Scaffold(
      appBar: AppBar(
        title: Text("Foreign Stock"),
        actions: <Widget>[
          PopupMenuButton<StockSort>(
            icon: Icon(
              Icons.sort,
            ),
            onSelected: _sortStocks,
            itemBuilder: (BuildContext context) {
              return _popupChoices.map((StockSort choice) {
                return PopupMenuItem<StockSort>(
                  value: choice,
                  child: Text(choice.description),
                );
              }).toList();
            },
          ),
          IconButton(
            icon: Icon(Icons.settings),
            onPressed: () {
              _showOptionsDialog();
            },
          ),
        ],
      ),
      body: Stack(
        alignment: Alignment.topCenter,
        children: <Widget>[
          FutureBuilder(
            future: _apiCalled,
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (_apiSuccess) {
                  return ListView(
                    children: _stockItems(),
                  );
                } else {
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        'OPS!',
                        style: TextStyle(
                            color: Colors.red,
                            fontSize: 20,
                            fontWeight: FontWeight.bold),
                      ),
                      Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 50, vertical: 20),
                        child: Text(
                          'There was an error getting the information, please '
                          'try again later!',
                        ),
                      ),
                    ],
                  );
                }
              } else {
                return Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text('Fetching data...'),
                      SizedBox(height: 30),
                      CircularProgressIndicator(),
                    ],
                  ),
                );
              }
            },
          ),

          // Sliding panel
          FutureBuilder(
            future: _apiCalled,
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (_apiSuccess) {
                  return SlidingUpPanel(
                    controller: _pc,
                    maxHeight: _panelHeightOpen,
                    minHeight: _panelHeightClosed,
                    renderPanelSheet: false,
                    backdropEnabled: true,
                    parallaxEnabled: true,
                    parallaxOffset: .5,
                    panelBuilder: (sc) => _bottomPanel(sc),
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(18.0),
                      topRight: Radius.circular(18.0),
                    ),
                    onPanelSlide: (double pos) => setState(() {
                      _fabHeight =
                          pos * (_panelHeightOpen - _panelHeightClosed) +
                              _initFabHeight;
                    }),
                  );
                } else {
                  return SizedBox.shrink();
                }
              } else {
                return SizedBox.shrink();
              }
            },
          ),

          // FAB
          FutureBuilder(
            future: _apiCalled,
            builder: (BuildContext context, AsyncSnapshot<dynamic> snapshot) {
              if (snapshot.connectionState == ConnectionState.done) {
                if (_apiSuccess) {
                  return Positioned(
                    right: 35.0,
                    bottom: _fabHeight,
                    child: FloatingActionButton.extended(
                      icon: Icon(Icons.filter_list),
                      label: Text("Filter"),
                      elevation: 4,
                      onPressed: () {
                        _pc.isPanelOpen ? _pc.close() : _pc.open();
                      },
                      backgroundColor: Colors.orange,
                    ),
                  );
                } else {
                  return SizedBox.shrink();
                }
              } else {
                return SizedBox.shrink();
              }
            },
          ),
        ],
      ),
    );
  }

  Widget _bottomPanel(ScrollController sc) {
    return Container(
      decoration: BoxDecoration(
          color: _themeProvider.background,
          borderRadius: BorderRadius.all(Radius.circular(24.0)),
          boxShadow: [
            BoxShadow(
              blurRadius: 2.0,
              color: Colors.orange[800],
            ),
          ]),
      margin: const EdgeInsets.all(24.0),
      child: Column(
        children: <Widget>[
          SizedBox(
            height: 12.0,
          ),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              Container(
                width: 30,
                height: 5,
                decoration: BoxDecoration(
                    color: Colors.grey[400],
                    borderRadius: BorderRadius.all(Radius.circular(12.0))),
              ),
            ],
          ),
          SizedBox(height: 40.0),
          SizedBox(height: 70, child: _toggleFlagsFilter()),
          SizedBox(height: 20.0),
          SizedBox(height: 35, child: _toggleTypeFilter()),
        ],
      ),
    );
  }

  Widget _toggleFlagsFilter() {
    return GridView.count(
        shrinkWrap: true,
        crossAxisCount: 2,
        scrollDirection: Axis.horizontal,
        mainAxisSpacing: 2.0,
        crossAxisSpacing: 2.0,
        childAspectRatio: 1,
        children: [
          Image.asset('images/flags/stock/argentina.png', width: 20),
          Image.asset('images/flags/stock/canada.png', width: 20),
          Image.asset('images/flags/stock/cayman.png', width: 20),
          Image.asset('images/flags/stock/china.png', width: 20),
          Image.asset('images/flags/stock/hawaii.png', width: 20),
          Image.asset('images/flags/stock/japan.png', width: 20),
          Image.asset('images/flags/stock/mexico.png', width: 20),
          Image.asset('images/flags/stock/south-africa.png', width: 20),
          Image.asset('images/flags/stock/switzerland.png', width: 20),
          Image.asset('images/flags/stock/uae.png', width: 20),
          Image.asset('images/flags/stock/uk.png', width: 20),
          Icon(
            Icons.select_all,
            color: _themeProvider.mainText,
          ),
        ].asMap().entries.map((widget) {
          return ToggleButtons(
            constraints: BoxConstraints(minWidth: 30.0),
            highlightColor: Colors.orange,
            selectedBorderColor: Colors.green,
            isSelected: [_filteredFlags[widget.key]],
            children: [widget.value],
            onPressed: (_) {
              setState(() {
                // Item 11 is the icon for selecting/deselecting all
                if (widget.key == 11) {
                  if (_filteredFlags[widget.key]) {
                    for (int i = 0; i < _filteredFlags.length; i++) {
                      _filteredFlags[i] = false;
                    }
                  } else {
                    for (int i = 0; i < _filteredFlags.length; i++) {
                      _filteredFlags[i] = true;
                    }
                  }
                } else {
                  // Any country flag state change is handled here
                  _filteredFlags[widget.key] = !_filteredFlags[widget.key];
                  // Then, we check if we need to select Item 11
                  bool allFlagsSelected = true;
                  for (int i = 0; i < _filteredFlags.length - 1; i++) {
                    if (_filteredFlags[i] == false) {
                      allFlagsSelected = false;
                    }
                  }
                  if (allFlagsSelected) {
                    _filteredFlags[11] = true;
                  } else {
                    _filteredFlags[11] = false;
                  }
                }
              });

              // Saving to shared preferences
              var saveList = List<String>();
              for (var b in _filteredFlags) {
                b ? saveList.add('1') : saveList.add('0');
              }
              SharedPreferencesModel().setStockCountryFilter(saveList);

              // Applying filter
              _filterAndSortMainList();
            },
          );
        }).toList());
  }

  Widget _toggleTypeFilter() {
    return GridView.count(
        shrinkWrap: true,
        crossAxisCount: 1,
        scrollDirection: Axis.horizontal,
        mainAxisSpacing: 2.0,
        crossAxisSpacing: 2.0,
        childAspectRatio: 1,
        children: [
          Image.asset(
            'images/icons/ic_flower_black_48dp.png',
            width: 20,
            color: _themeProvider.mainText,
          ),
          Image.asset(
            'images/icons/ic_dog_black_48dp.png',
            width: 20,
            color: _themeProvider.mainText,
          ),
          Image.asset(
            'images/icons/ic_pill_black_48dp.png',
            width: 20,
            color: _themeProvider.mainText,
          ),
          Icon(
            Icons.add_to_photos,
            color: _themeProvider.mainText,
          ),
        ].asMap().entries.map((widget) {
          return ToggleButtons(
            constraints: BoxConstraints(minWidth: 30.0),
            children: [widget.value],
            highlightColor: Colors.orange,
            selectedBorderColor: Colors.green,
            isSelected: [_filteredTypes[widget.key]],
            onPressed: (_) {
              setState(() {
                // Any item type state change is handled here
                _filteredTypes[widget.key] = !_filteredTypes[widget.key];
              });

              // Saving to shared preferences
              var saveList = List<String>();
              for (var b in _filteredTypes) {
                b ? saveList.add('1') : saveList.add('0');
              }
              SharedPreferencesModel().setStockTypeFilter(saveList);

              // Applying filter
              _filterAndSortMainList();
            },
          );
        }).toList());
  }

  List<Widget> _stockItems() {
    var thisStockList = List<Widget>();

    Widget countriesFilterDetails = Padding(
      padding: EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Row(
        children: <Widget>[
          Text(
            'Countries: ',
            style: TextStyle(fontSize: 11),
          ),
          SizedBox(width: 6),
          Flexible(
              child: Text(
            _countriesFilteredText,
            style: TextStyle(fontSize: 11),
          )),
        ],
      ),
    );

    Widget typesFilterDetails = Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20),
      child: Row(
        children: <Widget>[
          Text(
            'Items: ',
            style: TextStyle(fontSize: 11),
          ),
          SizedBox(width: 6),
          Flexible(
              child: Text(
            _typesFilteredText,
            style: TextStyle(fontSize: 11),
          )),
        ],
      ),
    );

    thisStockList.add(countriesFilterDetails);
    thisStockList.add(typesFilterDetails);

    for (var stock in _filteredStocks.stocks) {
      Widget stockDetails = Card(
        child: Padding(
          padding: const EdgeInsets.all(8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  _firstRow(stock),
                  SizedBox(height: 10),
                  _secondRow(stock),
                ],
              ),
              _countryFlag(stock),
            ],
          ),
        ),
      );

      thisStockList.add(stockDetails);
    }
    thisStockList.add(SizedBox(
      height: 100,
    ));
    return thisStockList;
  }

  Row _firstRow(Stock stock) {
    return Row(
      children: <Widget>[
        Image.asset('images/torn_items/small/${stock.itemId}_small.png'),
        Padding(
          padding: EdgeInsets.only(right: 10),
        ),
        SizedBox(
          width: 100,
          child: Text(stock.itemName),
        ),
        Padding(
          padding: EdgeInsets.only(right: 15),
        ),
        SizedBox(
          width: 55,
          child: Text(
            'x${stock.abroadQuantity}',
            style: TextStyle(
              color: stock.abroadQuantity > 0 ? Colors.green : Colors.red,
              fontWeight: stock.abroadQuantity > 0
                  ? FontWeight.bold
                  : FontWeight.normal,
            ),
          ),
        ),
        _returnLastUpdated(stock),
      ],
    );
  }

  Row _secondRow(Stock stock) {
    // Currency configuration
    final costCurrency = new NumberFormat("#,##0", "en_US");

    // Item cost
    Widget costWidget;
    costWidget = Text(
      '\$${costCurrency.format(stock.abroadCost)}',
      style: TextStyle(fontWeight: FontWeight.bold),
    );

    // Profit and profit per hour
    Widget profitWidget;
    Widget profitPerMinuteWidget;
    var apiModel = _allTornItems;
    if (apiModel is ItemsModel) {
      final profitColor = stock.value <= 0 ? Colors.red : Colors.green;

      String profitFormatted = calculateProfit(stock.value.abs());
      if (stock.value <= 0) {
        profitFormatted = '-\$$profitFormatted';
      } else {
        profitFormatted = '+\$$profitFormatted';
      }

      profitWidget = Text(
        profitFormatted,
        style: TextStyle(color: profitColor),
      );

      // Profit per hour
      String profitPerHourFormatted =
          calculateProfit((stock.profit * _capacity).abs());
      if (stock.profit <= 0) {
        profitPerHourFormatted = '-\$$profitPerHourFormatted';
      } else {
        profitPerHourFormatted = '+\$$profitPerHourFormatted';
      }

      profitPerMinuteWidget = Text(
        '($profitPerHourFormatted/hour)',
        style: TextStyle(color: profitColor),
      );
    } else if (apiModel is ApiError) {
      // We don't necessarily need Torn API to be up
      profitWidget = SizedBox.shrink();
      profitPerMinuteWidget = SizedBox.shrink();
    }

    return Row(
      children: <Widget>[
        costWidget,
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: profitWidget,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 8.0),
          child: profitPerMinuteWidget,
        ),
      ],
    );
  }

  String calculateProfit(int moneyInput) {
    final profitCurrencyHigh = new NumberFormat("#,##0.0", "en_US");
    final costCurrencyLow = new NumberFormat("#,##0", "en_US");
    String profitFormat;

    // Money standards to reduce string length (adding two zeros for .00)
    final billion = 1000000000;
    final million = 1000000;
    final thousand = 1000;

    // Profit
    if (moneyInput < -billion || moneyInput > billion) {
      final profitBillion = moneyInput / billion;
      profitFormat = '${profitCurrencyHigh.format(profitBillion)}B';
    } else if (moneyInput < -million || moneyInput > million) {
      final profitMillion = moneyInput / million;
      profitFormat = '${profitCurrencyHigh.format(profitMillion)}M';
    } else if (moneyInput < -thousand || moneyInput > thousand) {
      final profitThousand = moneyInput / thousand;
      profitFormat = '${profitCurrencyHigh.format(profitThousand)}K';
    } else {
      profitFormat = '${costCurrencyLow.format(moneyInput)}';
    }
    return profitFormat;
  }

  Widget _countryFlag(Stock stock) {
    String countryCode;
    String flag;
    switch (stock.countryName) {
      case CountryName.JAPAN:
        countryCode = 'JPN';
        flag = 'images/flags/stock/japan.png';
        break;
      case CountryName.HAWAII:
        countryCode = 'HAW';
        flag = 'images/flags/stock/hawaii.png';
        break;
      case CountryName.CHINA:
        countryCode = 'CHN';
        flag = 'images/flags/stock/china.png';
        break;
      case CountryName.ARGENTINA:
        countryCode = 'ARG';
        flag = 'images/flags/stock/argentina.png';
        break;
      case CountryName.UNITED_KINGDOM:
        countryCode = 'UK';
        flag = 'images/flags/stock/uk.png';
        break;
      case CountryName.CAYMAN_ISLANDS:
        countryCode = 'CAY';
        flag = 'images/flags/stock/cayman.png';
        break;
      case CountryName.SOUTH_AFRICA:
        countryCode = 'AFR';
        flag = 'images/flags/stock/south-africa.png';
        break;
      case CountryName.SWITZERLAND:
        countryCode = 'SWI';
        flag = 'images/flags/stock/switzerland.png';
        break;
      case CountryName.MEXICO:
        countryCode = 'MEX';
        flag = 'images/flags/stock/mexico.png';
        break;
      case CountryName.UAE:
        countryCode = 'UAE';
        flag = 'images/flags/stock/uae.png';
        break;
      case CountryName.CANADA:
        countryCode = 'CAN';
        flag = 'images/flags/stock/canada.png';
        break;
    }

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: <Widget>[
        Text(countryCode),
        Image.asset(
          flag,
          width: 30,
        ),
      ],
    );
  }

  Future<void> _fetchApiInformation() async {
    try {
      // Database API
      String urlDB = 'https://yata.alwaysdata.net/bazaar/abroad/export/';
      final responseDB = await http.get(urlDB).timeout(Duration(seconds: 10));
      if (responseDB.statusCode == 200) {
        _allStocks = foreignStockInModelFromJson(responseDB.body);
        _apiSuccess = true;
      } else {
        _apiSuccess = false;
      }
      _allTornItems = await TornApiCaller.items(widget.apiKey).getItems;

      // We need to calculate two additional values (stock value and profit)
      // before sorting the list for the first time. This values come from the
      // Torn API, so we need to match the item with the stock before.
      var itemList = _allTornItems.items.values.toList();
      for (var stock in _allStocks.stocks) {
        Item itemMatch = itemList[stock.itemId - 1];
        var priceDifference = itemMatch.marketValue - stock.abroadCost;
        stock.value = priceDifference;

        // Profit per hour
        int roundTripJapan = 158 * 2;
        int roundTripHawaii = 94 * 2;
        int roundTripChina = 169 * 2;
        int roundTripArgentina = 117 * 2;
        int roundTripUK = 111 * 2;
        int roundTripCayman = 25 * 2;
        int roundTripSouthAfrica = 208 * 2;
        int roundTripSwitzerland = 123 * 2;
        int roundTripMexico = 18 * 2;
        int roundTripUAE = 190 * 2;
        int roundTripCanada = 29 * 2;

        int profitPerHour;
        switch (stock.countryName) {
          case CountryName.JAPAN:
            profitPerHour = (priceDifference / roundTripJapan * 60).round();
            break;
          case CountryName.HAWAII:
            profitPerHour = (priceDifference / roundTripHawaii * 60).round();
            break;
          case CountryName.CHINA:
            profitPerHour = (priceDifference / roundTripChina * 60).round();
            break;
          case CountryName.ARGENTINA:
            profitPerHour = (priceDifference / roundTripArgentina * 60).round();
            break;
          case CountryName.UNITED_KINGDOM:
            profitPerHour = (priceDifference / roundTripUK * 60).round();
            break;
          case CountryName.CAYMAN_ISLANDS:
            profitPerHour = (priceDifference / roundTripCayman * 60).round();
            break;
          case CountryName.SOUTH_AFRICA:
            profitPerHour =
                (priceDifference / roundTripSouthAfrica * 60).round();
            break;
          case CountryName.SWITZERLAND:
            profitPerHour =
                (priceDifference / roundTripSwitzerland * 60).round();
            break;
          case CountryName.MEXICO:
            profitPerHour = (priceDifference / roundTripMexico * 60).round();
            break;
          case CountryName.UAE:
            profitPerHour = (priceDifference / roundTripUAE * 60).round();
            break;
          case CountryName.CANADA:
            profitPerHour = (priceDifference / roundTripCanada * 60).round();
            break;
        }
        stock.profit = profitPerHour;
      }

      // This will trigger a filter by flags, types and also sorting
      _filterAndSortMainList();
    } catch (e) {
      _apiSuccess = false;
    }
  }

  Row _returnLastUpdated(Stock stock) {
    var stockTime = DateTime.fromMillisecondsSinceEpoch(stock.timestamp * 1000);
    var timeDifference = DateTime.now().difference(stockTime);
    var timeString;
    var color;
    if (timeDifference.inMinutes < 1) {
      timeString = 'now';
      color = Colors.green;
    } else if (timeDifference.inMinutes == 1 && timeDifference.inHours < 1) {
      timeString = '1 min';
      color = Colors.green;
    } else if (timeDifference.inMinutes > 1 && timeDifference.inHours < 1) {
      timeString = '${timeDifference.inMinutes} min';
      color = Colors.green;
    } else if (timeDifference.inHours == 1 && timeDifference.inDays < 1) {
      timeString = '1 hour';
      color = Colors.orange;
    } else if (timeDifference.inHours > 1 && timeDifference.inDays < 1) {
      timeString = '${timeDifference.inHours} hours';
      color = Colors.red;
    } else if (timeDifference.inDays == 1) {
      timeString = '1 day';
      color = Colors.green;
    } else {
      timeString = '${timeDifference.inDays} days';
      color = Colors.green;
    }

    return Row(
      children: <Widget>[
        Icon(
          Icons.access_time,
          size: 14,
          color: color,
        ),
        Padding(
          padding: const EdgeInsets.only(left: 5),
          child: Text(
            timeString,
            style: TextStyle(color: color),
          ),
        ),
      ],
    );
  }

  void _filterAndSortMainList() {
    // Edit countries string
    _countriesFilteredText = '';
    bool firstCountry = true;
    int totalCountriesShown = 0;
    for (var i = 0; i < _filteredFlags.length - 1; i++) {
      if (_filteredFlags[i]) {
        _countriesFilteredText +=
            firstCountry ? _countryCodes[i] : ', ${_countryCodes[i]}';
        firstCountry = false;
        totalCountriesShown++;
      }
    }
    if (totalCountriesShown == 0) {
      _countriesFilteredText = 'NONE';
    } else if (totalCountriesShown == 11) {
      _countriesFilteredText = 'ALL';
    }

    // Filter countries
    var countryList = List<Stock>();
    for (var stock in _allStocks.stocks) {
      switch (stock.countryName) {
        case CountryName.ARGENTINA:
          if (_filteredFlags[0]) {
            countryList.add(stock);
          }
          break;
        case CountryName.CANADA:
          if (_filteredFlags[1]) {
            countryList.add(stock);
          }
          break;
        case CountryName.CAYMAN_ISLANDS:
          if (_filteredFlags[2]) {
            countryList.add(stock);
          }
          break;
        case CountryName.CHINA:
          if (_filteredFlags[3]) {
            countryList.add(stock);
          }
          break;
        case CountryName.HAWAII:
          if (_filteredFlags[4]) {
            countryList.add(stock);
          }
          break;
        case CountryName.JAPAN:
          if (_filteredFlags[5]) {
            countryList.add(stock);
          }
          break;
        case CountryName.MEXICO:
          if (_filteredFlags[6]) {
            countryList.add(stock);
          }
          break;
        case CountryName.SOUTH_AFRICA:
          if (_filteredFlags[7]) {
            countryList.add(stock);
          }
          break;
        case CountryName.SWITZERLAND:
          if (_filteredFlags[8]) {
            countryList.add(stock);
          }
          break;
        case CountryName.UAE:
          if (_filteredFlags[9]) {
            countryList.add(stock);
          }
          break;
        case CountryName.UNITED_KINGDOM:
          if (_filteredFlags[10]) {
            countryList.add(stock);
          }
          break;
      }
    }

    // Edit drug string
    _typesFilteredText = '';
    bool firstType = true;
    int totalTypesShown = 0;
    for (var i = 0; i < _filteredTypes.length; i++) {
      if (_filteredTypes[i]) {
        _typesFilteredText += firstType ? _typeCodes[i] : ', ${_typeCodes[i]}';
        firstType = false;
        totalTypesShown++;
      }
    }
    if (totalTypesShown == 0) {
      _typesFilteredText = 'NONE';
    } else if (totalTypesShown == 4) {
      _typesFilteredText = 'ALL';
    }

    // Drug filtering
    var drugList = List<Stock>();
    for (var stock in countryList) {
      switch (stock.itemType) {
        case 'Flower':
          if (_filteredTypes[0]) {
            drugList.add(stock);
          }
          break;
        case 'Plushie':
          if (_filteredTypes[1]) {
            drugList.add(stock);
          }
          break;
        case 'Drug':
          if (_filteredTypes[2]) {
            drugList.add(stock);
          }
          break;
        default:
          if (_filteredTypes[3]) {
            drugList.add(stock);
          }
          break;
      }
    }

    setState(() {
      _filteredStocks.stocks = List<Stock>.from(drugList);
      _sortStocks(_currentSort);
    });
  }

  void _sortStocks(StockSort choice) {
    _currentSort = choice;
    setState(() {
      switch (choice.type) {
        case StockSortType.country:
          _filteredStocks.stocks.sort(
              (a, b) => a.countryName.index.compareTo(b.countryName.index));
          SharedPreferencesModel().setStockSort('country');
          break;
        case StockSortType.name:
          _filteredStocks.stocks
              .sort((a, b) => a.itemName.compareTo(b.itemName));
          SharedPreferencesModel().setStockSort('name');
          break;
        case StockSortType.type:
          _filteredStocks.stocks
              .sort((a, b) => a.itemType.compareTo(b.itemType));
          SharedPreferencesModel().setStockSort('type');
          break;
        case StockSortType.price:
          _filteredStocks.stocks
              .sort((a, b) => b.abroadCost.compareTo(a.abroadCost));
          SharedPreferencesModel().setStockSort('price');
          break;
        case StockSortType.value:
          _filteredStocks.stocks.sort((a, b) => b.value.compareTo(a.value));
          SharedPreferencesModel().setStockSort('value');
          break;
        case StockSortType.profit:
          _filteredStocks.stocks.sort((a, b) => b.profit.compareTo(a.profit));
          SharedPreferencesModel().setStockSort('profit');
          break;
      }
    });
  }

  Future _restoreSharedPreferences() async {
    var flagStrings = await SharedPreferencesModel().getStockCountryFilter();
    for (var i = 0; i < flagStrings.length; i++) {
      flagStrings[i] == '0'
          ? _filteredFlags[i] = false
          : _filteredFlags[i] = true;
    }

    var typesStrings = await SharedPreferencesModel().getStockTypeFilter();
    for (var i = 0; i < typesStrings.length; i++) {
      typesStrings[i] == '0'
          ? _filteredTypes[i] = false
          : _filteredTypes[i] = true;
    }

    var sortString = await SharedPreferencesModel().getStockSort();
    StockSortType sortType;
    if (sortString == 'country') {
      sortType = StockSortType.country;
    } else if (sortString == 'name') {
      sortType = StockSortType.name;
    } else if (sortString == 'type') {
      sortType = StockSortType.type;
    } else if (sortString == 'price') {
      sortType = StockSortType.price;
    } else if (sortString == 'value') {
      sortType = StockSortType.value;
    } else if (sortString == 'profit') {
      sortType = StockSortType.profit;
    }
    _currentSort = StockSort(type: sortType);

    _capacity = await SharedPreferencesModel().getStockCapacity();
  }

  Future<void> _showOptionsDialog() {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0.0,
          backgroundColor: Colors.transparent,
          content: SingleChildScrollView(
            child: StocksOptionsDialog(
              capacity: _capacity,
              callBack: _onCapacityChanged,
            ),
          ),
        );
      },
    );
  }

  void _onCapacityChanged(int newCapacity) {
    setState(() {
      _capacity = newCapacity;
    });
  }

}
