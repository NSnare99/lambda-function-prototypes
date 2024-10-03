// import 'dart:convert';
// import 'package:base/models/ModelProvider.dart';
// import 'package:base/utilities/hive/hive_app_settings.dart';
// import 'package:base/utilities/requests/graphql.dart';
// import 'package:base/utilities/safe_print.dart';
// import 'package:base/utilities/sorting.dart';
// import 'package:base/views/adaptive_table.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter/services.dart';
// import 'package:go_router/go_router.dart';
// import 'package:rms/view/explore/old/rms_base_explore.dart';

// class OrganizationsExplorer extends StatelessWidget {
//   final bool isNested;
//   final void Function()? onSubmit;
//   const OrganizationsExplorer({Key? key, required this.isNested, this.onSubmit}) : super(key: key);

//   @override
//   Widget build(BuildContext context) {
//     return RMSBaseExplore<Organization>(
//       getItems: _getItems,
//       searchLabel: 'Search by Organization name',
//       filterFunction: (element, searchFilter) =>
//           element.name.toLowerCase().contains(searchFilter.toLowerCase()),
//       getSearchItems: _getSearchItems,
//       adaptiveTable: _organizationsTable,
//     );
//   }

//   Widget _organizationsTable(
//     BuildContext context,
//     Iterable<Organization> items,
//     void Function(Iterable<Organization> items) updateItems,
//   ) {
//     return AdaptiveTable<Organization>(
//       breakpoint: 720,
//       items: items.toList(),
//       itemBuilder: (item, index) {
//         return ListTile(
//           title: Text(item.name),
//           subtitle: Text(item.addresses?.first.label ?? ""),
//           trailing: IconButton(
//             icon: const Icon(Icons.info_outline),
//             onPressed: () {
//               GoRouter.of(context).go('${GoRouterState.of(context).uri}/${item.id}');
//             },
//           ),
//         );
//       },
//       columnWidthPercentages: const [30, 70],
//       columns: <DataColumn>[
//         DataColumn(
//           label: const Text(
//             'Organization Name',
//           ),
//           onSort: (columnIndex, _) {
//             updateItems(
//               <Organization>[...Sorting<Organization>().onSortColumn(items, columnIndex, 'name')],
//             );
//           },
//         ),
//         DataColumn(
//           label: const Text(
//             'Location',
//           ),
//           onSort: (columnIndex, _) {
//             updateItems(<Organization>[
//               ...Sorting<Organization>().onSortColumn(items, columnIndex, 'address'),
//             ]);
//           },
//         ),
//       ],
//       rowBuilder: (item, index) => DataRow.byIndex(
//         index: index,
//         // onLongPress: () {
//         // },
//         cells: [
//           DataCell(
//             Text(item.name),
//           ),
//           DataCell(
//             Row(
//               children: [
//                 Text(item.addresses?.first.label ?? ""),
//                 const Spacer(),
//                 if (isNested)
//                   IconButton(onPressed: onSubmit, icon: const Icon(Icons.add))
//                 else ...[
//                   IconButton(
//                     onPressed: () {
//                       GoRouter.of(context).go('${GoRouterState.of(context).uri}/${item.id}');
//                     },
//                     icon: const Icon(Icons.edit_outlined),
//                   ),
//                   const SizedBox(
//                     width: 20,
//                   ),
//                   IconButton(
//                     onPressed: () {
//                       Clipboard.setData(ClipboardData(text: '${Uri.base}/${item.id}')).then((_) {
//                         ScaffoldMessenger.of(context)
//                             .showSnackBar(const SnackBar(content: Text("Copied to clipboard")));
//                       });
//                     },
//                     icon: const Icon(Icons.link_outlined),
//                   ),
//                   const SizedBox(
//                     width: 20,
//                   ),
//                   IconButton(
//                     onPressed: () {
//                       _deleteOrganization(item);
//                     },
//                     icon: const Icon(Icons.delete_outline),
//                   ),
//                 ],
//               ],
//             ),
//           ),
//         ],
//       ),
//     );
//   }

//   String _getQuery({required String alias, String? filter, int? limit}) {
//     return '''
//         $alias: listOrganizations(${limit != null ? "limit: $limit," : ""},  ${filter ?? ""},) {
//         items {
//           id
//           name
//           description
//           addresses {
//             items {
//               id
//               type
//               label
//             }
//           }
//           phones {
//             items {
//             id
//             type
//             phone
//             }
//           }
//         }
//         nextToken
//       }
//     ''';
//   }

  // Future<List<Organization>> _getItems() async {
  //   String alias = 'list';
  //   String query = "query _ {${_getQuery(alias: alias, limit: 15)}}";
  //   Map<String, dynamic> result = jsonDecode((await gqlQuery(query)).body);
  //   List<Organization> tmpObjectsList = <Organization>[];
  //   for (Map<String, dynamic> element in result['data'][alias]['items']) {
  //     Map<String, dynamic>? serializedJson = serializeDataFromAppSync(json: element);
  //     Organization? tmpObject =
  //         serializedJson != null ? Organization.fromJson(serializedJson) : null;
  //     if (tmpObject != null && !tmpObjectsList.contains(tmpObject)) {
  //       tmpObjectsList.add(tmpObject);
  //     }
  //   }
  //   return tmpObjectsList;
  // }

  // Future<List<Organization>> _getSearchItems(String searchTerm) async {
  //   String alias = 'list';
  //   String query =
  //       "query _ {${_getQuery(alias: alias, filter: 'filter: {name: {contains: "$searchTerm"}}', limit: 15)}}";
  //   Map<String, dynamic> result = jsonDecode((await gqlQuery(query)).body);
  //   List<Organization> tmpObjectsList = <Organization>[];
  //   for (var element in result['data'][alias]['items']) {
  //     Organization tmpObject = Organization.fromJson(element);
  //     if (!tmpObjectsList.contains(tmpObject)) {
  //       tmpObjectsList.add(tmpObject);
  //     }
  //   }
  //   return tmpObjectsList;
  // }

//   void _deleteOrganization(Organization organization) async {
//     Map<String, dynamic> body = {};
//     String query = """
//   mutation _ {
//     deleteOrganization(input: {id: "${organization.id}", _version: ${await HiveAppSettings().getVersionFromId(id: organization.id)}}) {
//         id
//         _version
//         _deleted
//       }
//     }""";
//     body['query'] = query;

//     Map<String, dynamic> result2 = jsonDecode(
//       (await gqlMutation(
//         input: body,
//         model: ModelProvider.instance.getModelTypeByModelName("Organization"),
//         mutationType: GraphQLMutationType.create,
//       ))
//           .body,
//     );
//   }
// }
