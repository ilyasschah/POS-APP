using MediatR;
using Products.Api.Helpers;
using Products.Api.Models;
using Products.Api.Repository;

namespace Products.Api.Queries.CustomerQuery.Get
{
    public class GetAllCustomersQuery : IRequest<List<CustomerDto>>
    {
        public class GetAllCustomersQueryHandler(CustomerRepository customerRepositor) : IRequestHandler<GetAllCustomersQuery, List<CustomerDto>>
        {
            private readonly CustomerRepository _customerRepository = customerRepositor;

            public async Task<List<CustomerDto>> Handle(GetAllCustomersQuery request, CancellationToken cancellationToken)
            {
                var barcode = await _customerRepository.GetAllCustomers();
                return barcode.Select(MapperCustomer.MapToCustomer).ToList();
            }
        }
    }
}
