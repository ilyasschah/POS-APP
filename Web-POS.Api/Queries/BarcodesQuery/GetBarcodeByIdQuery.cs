using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.BarcodesQuery.Get
{
    public class GetBarcodeByIdQuery : IRequest<BarcodeDto?>
    {
        public int Id { get; set; }
        public int CompanyId { get; set; }

        public GetBarcodeByIdQuery(int id, int companyId)
        {
            Id = id;
            CompanyId = companyId;
        }

        public class GetBarcodeByIdQueryHandler : IRequestHandler<GetBarcodeByIdQuery, BarcodeDto?>
        {
            private readonly BarcodeRepository _repository;

            public GetBarcodeByIdQueryHandler(BarcodeRepository repository)
            {
                _repository = repository;
            }

            public async Task<BarcodeDto?> Handle(GetBarcodeByIdQuery request, CancellationToken cancellationToken)
            {
                var entity = await _repository.GetBarCodeByIdQuery(request.Id, request.CompanyId);
                return entity == null ? null : MapperBarcode.MapToBarcodeDto(entity);
            }
        }
    }
}