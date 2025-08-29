using MediatR;
using Sales.Api.Helpers;
using Sales.Api.Models;
using Sales.Api.Repository;

namespace Sales.Api.Queries.CustomerQuery.Get
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
