import 'package:cari_hesapp_lite/components/card/custom_card.dart';
import 'package:cari_hesapp_lite/components/dialogs/custom_alert_dialog.dart';
import 'package:cari_hesapp_lite/enums/cari_islem_turu.dart';
import 'package:cari_hesapp_lite/enums/gelir_gider_turu.dart';
import 'package:cari_hesapp_lite/enums/hesap_hareket_turu.dart';
import 'package:cari_hesapp_lite/enums/irsaliye_turu_enum.dart';
import 'package:cari_hesapp_lite/models/cari_islem.dart';
import 'package:cari_hesapp_lite/models/hesap_hareket.dart';
import 'package:cari_hesapp_lite/utils/date_format.dart';
import 'package:cari_hesapp_lite/utils/print.dart';
import 'package:cari_hesapp_lite/utils/view_route_util.dart';
import 'package:cari_hesapp_lite/views/cari/cari_view/cari_view_model.dart';
import 'package:cari_hesapp_lite/views/cari_transaction/transaction_adding_view/new_cari_trans_view/new_cari_trans_view.dart';
import 'package:cari_hesapp_lite/views/cari_transaction/transaction_adding_view/new_cari_trans_view/new_cari_trans_view_model.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class CariTransPage extends StatelessWidget {
  late CariViewModel viewModel;
  late CariViewModel viewModelUnlistened;

  @override
  Widget build(BuildContext context) {
    viewModel = Provider.of<CariViewModel>(context);
    viewModelUnlistened = Provider.of<CariViewModel>(context, listen: false);
    var list = viewModel.getlist;
    return Column(
      children: [
        const MyCard(
          padding: EdgeInsets.all(3),
          child: Text("İşlemler"), /**/
        ),
        ListView.builder(
          physics: const NeverScrollableScrollPhysics(),
          shrinkWrap: true,
          //  query: viewModelUnlistened.getCariIslemlerQuery(),
          itemCount: list.length,
          itemBuilder: (context, index) {
            var islem = list[index];

            bas("islem.runtimeType");
            bas(islem.runtimeType);

            return Padding(
              padding: const EdgeInsets.all(4.0),
              child: ListTile(
                title: Text(islem.runtimeType == CariIslemModel
                    ? (islem as CariIslemModel).islemTuru!.stringValue +
                        ": " +
                        (islem).evrakTuru!.stringValue
                    : (islem as HesapHareket).hesapHareketTuru!.stringValue +
                        " " +
                        (islem).gelirGiderTuru!.stringValue!),
                subtitle: Text(dateFormatterToString(islem.islemTarihi!)),
                trailing: Text(((islem.runtimeType == CariIslemModel &&
                            (islem as CariIslemModel).islemTuru ==
                                CariIslemTuru.alis)
                        ? "-"
                        : (islem.runtimeType == HesapHareket &&
                                (islem as HesapHareket).gelirGiderTuru ==
                                    GelirGiderTuru.gelir
                            ? "-"
                            : "")) +
                    (islem.toplamTutar ?? 0).toStringAsFixed(2) +
                    " " +
                    ("₺")),
                /* tileColor: (islem.runtimeType == CariIslemModel) &&
                        (islem as CariIslemModel).evrakTuru! ==
                            IrsaliyeTuru.sevkIrsaliyesi
                    ? Colors.red.shade50
                    : null, */
                onTap: () {
                  if (islem.runtimeType == CariIslemModel) {
                   
                      goToView(context,
                          viewToGo: const CariTransactionAddView(),
                          viewModel:
                              CariTransactionAddViewModel.showExistHareket(
                                  islem as CariIslemModel, viewModel.cariKart));
                    
                  } 
                },

                /*  Text((islem.toplamTutar ?? 0).toStringAsFixed(2)), */
                /* leading: Icon((islem.islemTuru == CariIslemTuru.alis)
                      ? Icons.arrow_circle_down_sharp
                      : Icons.arrow_circle_up_sharp), */
                /*   subtitle: Text(
                    islem.evrakTuru?.stringValue ?? "null",
                    style: TextStyle(
                        color: (islem.evrakTuru == IrsaliyeTuru.sevkIrsaliyesi)
                            ? Colors.red
                            : null),
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.format_align_right_sharp),
                    onPressed: () {
                      goToView(context,
                          viewToGo: CariTransactionAddView(),
                          viewModel: CariTransactionAddViewModel.showExistHareket(
                              islem));
                    },
                  ), */
                shape: RoundedRectangleBorder(
                    side: const BorderSide(width: 1, color: Colors.black),
                    borderRadius: BorderRadiusDirectional.circular(12)),
              ),
            );
          },
        ),
      ],
    );
  }
}
