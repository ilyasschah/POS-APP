using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CustomerQuery.Get
{
    public class GetAllCustomersDiscountQuery : IRequest<List<CustomerDiscountDto>>
    {
        public class GetAllCustomersDiscountQueryHandler : IRequestHandler<GetAllCustomersDiscountQuery , List<CustomerDiscountDto>>
        {
            private readonly CustomerDiscountRepository _customerdiscountRepository;
            public GetAllCustomersDiscountQueryHandler(CustomerDiscountRepository customerDiscountRepository)
            {
                _customerdiscountRepository = customerDiscountRepository;
            }
            public async Task<List<CustomerDiscountDto>> Handle(GetAllCustomersDiscountQuery request , CancellationToken cancellationToken)
            {
                var customerdiscount = await _customerdiscountRepository.GetAllCustomerDiscount();
                return customerdiscount.Select(MapperCustomerDiscount.MapToCustomerDiscount).ToList();
            }
        }
    }
}
