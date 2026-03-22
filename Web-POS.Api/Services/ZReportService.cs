using Api.Domain;
using Api.Repository;

namespace Api.Services
{
    public class ZReportservice
    {
        public ZReportRepository _ZReportRepository;
        public ZReportservice(ZReportRepository ZReportRepository)
        {
            _ZReportRepository = ZReportRepository;
        }
        public async Task<bool> Create(int number,int fromdocumentid,int todocuemntid)
        {
            var cexist = _ZReportRepository.Exist(number);
            if (cexist == true)
                throw new InvalidOperationException($"A ZReport with the number '{number}' already exists.");
            var newZReport = ZReport.Create(number, fromdocumentid, todocuemntid);
            await _ZReportRepository.Add(newZReport);
            return true;
        }
        public async Task<bool> Delete( int id)
        {
            var entity = await _ZReportRepository.GetByIdAsync(id);
            if (entity == null)
                return false; // Or throw
            await _ZReportRepository.DeleteZReportAsync(entity);
            return true;
        }
    }
}
