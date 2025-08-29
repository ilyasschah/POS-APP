using MediatR;
using Products.Api.Domain;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.TaxesQuery.Get
{
    public class GetAllTaxesQuery : IRequest<List<TaxDto>>
    {

    }
    public class GetAllTaxesQueryHandler : IRequestHandler<GetAllTaxesQuery, List<TaxDto>>
    {
        private readonly TaxRepository _taxRepository;
        public GetAllTaxesQueryHandler(TaxRepository taxRepository)
        {
            _taxRepository = taxRepository;
        }
        public async Task<List<TaxDto>> Handle(GetAllTaxesQuery request, CancellationToken cancellationToken)
        {
            var taxes = await _taxRepository.GetAllTaxesAsync();
            return taxes.Select(MapperTax.MapToTax).ToList();
        }
    }
}