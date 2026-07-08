using MediatR;
using Api.Models;
using Api.Repository;
using Api.Helpers;

namespace Api.Queries.PaymentQuery
{
    public class GetUnreportedPaymentsQuery : IRequest<IEnumerable<PaymentDto?>>
    {
        public int CompanyId { get; set; }

        public GetUnreportedPaymentsQuery(int companyId)
        {
            CompanyId = companyId;
        }

        public class GetUnreportedPaymentsQueryHandler : IRequestHandler<GetUnreportedPaymentsQuery, IEnumerable<PaymentDto?>>
        {
            private readonly PaymentRepository _repository;

            public GetUnreportedPaymentsQueryHandler(PaymentRepository repository)
            {
                _repository = repository;
            }

            public async Task<IEnumerable<PaymentDto?>> Handle(GetUnreportedPaymentsQuery request, CancellationToken cancellationToken)
            {
                var unreportedPayments = await _repository.GetUnreportedPaymentsAsync(request.CompanyId);
                return unreportedPayments.Select(MapperPayment.MapToPaymentDto);
            }
        }
    }
}